import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/auth/jwt_decoder.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/caixa_dtos.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/cx_config.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_response.dart';
import 'package:rabbit_pdv/features/provisionamento/data/caixa_fisico_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/pdv_fisico.dart';

enum SessionStatus { iniciando, resolvendoTerminal, abrindoCaixa, pronto, erro }

/// Estado da carga do cx-config (contrato v3 §5). O diálogo de sangria usa isto
/// para decidir entre usar o valor, mostrar "resolvendo" ou cair no fallback.
enum CxConfigStatus { desconhecido, carregando, carregado, falhou }

/// Sessão de runtime do PDV: identidade do operador (claims do JWT) +
/// identidade do terminal (da ativação) + caixa aberto.
///
/// O contexto do caixa NÃO vem de Env: `cashRegisterId` vem da ativação
/// (TerminalContextStore) e `terminalId`/`defaultWarehouseId`/`name` vêm do
/// caixa físico (GET /pdv/caixas-fisicos/{id}), com cache local.
class CaixaSessionController extends ChangeNotifier {
  CaixaSessionController(
    this._caixa,
    this._tokens,
    this._terminalCtx,
    this._caixasFisicos,
  ) {
    bootstrap();
  }

  final CaixaRepository _caixa;
  final TokenStore _tokens;
  final TerminalContextStore _terminalCtx;
  final CaixaFisicoRepository _caixasFisicos;

  SessionStatus _status = SessionStatus.iniciando;
  SessionStatus get status => _status;

  String? _erro;
  String? get erro => _erro;

  String? _employeeId; // JWT.sub → cashierId / openedBy
  String? _authUserId; // JWT.auth_user_id (fallback p/ openedBy)
  Set<String> _permissoes = const {}; // JWT.permissions (codes literais)

  String? _cashRegisterId;
  String? _terminalId;
  String? _defaultWarehouseId;
  PdvFisico? _pdv;

  // ── cx-config (contrato v3 §5) ──
  // Pre-warm não-bloqueante no boot; garantido no open do diálogo de sangria.
  // maloteHabilitado não muda dentro do turno (mudança só vale no próximo
  // boot), então uma carga bem-sucedida vale para a sessão toda.
  CxConfigResponse? _cxConfig;
  CxConfigStatus _cxConfigStatus = CxConfigStatus.desconhecido;
  Future<void>? _cxConfigInFlight;

  // ── Semáforo de teto ──
  // Estado corrente do teto, alimentado por vendas e movimentos. Ver [aplicarTeto].
  CashCeilingStatus? _cashCeilingStatus;

  CaixaSessionResponse? _caixaSessao;
  CaixaSessionResponse? get caixaSessao => _caixaSessao;

  // Contexto para a venda.
  String? get cashierId => _employeeId;
  String get terminalId => _terminalId ?? '';
  String get cashRegisterId => _cashRegisterId ?? '';
  String get defaultWarehouseId =>
      _defaultWarehouseId ?? Env.defaultWarehouseId;
  bool get pronto => _status == SessionStatus.pronto;

  /// Rótulo do caixa para a topbar (name é NOT NULL no backend).
  String get caixaLabel => _pdv?.name ?? '';

  /// Permissão do operador pelo claim `permissions` do JWT (contrato v3 §2.0).
  /// Compare com o code literal, sem prefixo (ex.: `temPermissao('cx.reforco')`).
  /// Fail-closed: claim ausente → nenhuma permissão → sempre `false`.
  ///
  /// É gate de UX (esconder/pular passos), não de segurança — o backend sempre
  /// revalida no servidor.
  bool temPermissao(String code) => _permissoes.contains(code);

  /// Se o tenant usa o ciclo de malote → controla se o destino COFRE aparece
  /// na sangria. Default fail-safe (false) enquanto o cx-config não resolve.
  /// É conveniência de UX, não gate: o backend revalida no servidor.
  bool get maloteHabilitado => _cxConfig?.maloteHabilitado ?? false;

  /// Estado da carga do cx-config — o diálogo de sangria decide a partir daqui
  /// entre usar o valor, exibir "resolvendo" ou cair no fallback com aviso.
  CxConfigStatus get cxConfigStatus => _cxConfigStatus;

  /// Estado corrente do teto de caixa (semáforo), ou null se desconhecido/sem
  /// teto. Atualizado por [aplicarTeto] a partir de respostas de venda/movimento.
  CashCeilingStatus? get cashCeilingStatus => _cashCeilingStatus;

  Future<void> bootstrap() async {
    try {
      _set(SessionStatus.iniciando);
      _caixaSessao = null;
      _employeeId = null;
      _authUserId = null;
      _permissoes = const {};

      final token = _tokens.accessToken;
      if (token == null) {
        _falhar('Sem sessão autenticada. Faça login.');
        return;
      }
      final claims = decodeJwtPayload(token);
      _employeeId = claims['sub'] as String?;
      _authUserId = claims['auth_user_id'] as String?;
      _permissoes = _lerPermissoes(claims);

      if (kDebugMode) {
        debugPrint(
          '[caixa-session] identidade — employeeId=$_employeeId '
          'perms=${_permissoes.length}',
        );
      }

      _set(SessionStatus.resolvendoTerminal);
      if (!await _resolverTerminal()) return;

      _set(SessionStatus.abrindoCaixa);
      await _garantirCaixaAberto();

      // cx-config: pre-warm não-bloqueante, só se o caixa abriu. NÃO altera o
      // SessionStatus nem trava o boot — é apenas otimização de latência para o
      // diálogo de sangria. Falha aqui é tolerada; o open re-tenta.
      if (_status == SessionStatus.pronto) {
        unawaited(garantirCxConfig());
      }
    } catch (e) {
      _falhar('Erro no bootstrap: $e');
    }
  }

  /// Lê o claim `permissions` (array de strings) do payload do JWT, tolerante a
  /// ausência/formato inesperado (fail-closed → set vazio).
  static Set<String> _lerPermissoes(Map<String, dynamic> claims) {
    final raw = claims['permissions'];
    if (raw is List) return raw.whereType<String>().toSet();
    return const <String>{};
  }

  /// Resolve o contexto do terminal: cashRegisterId vem da ativação;
  /// terminalId/defaultWarehouseId/name vêm do caixa físico (com cache local).
  Future<bool> _resolverTerminal() async {
    final ctx = await _terminalCtx.carregar();
    if (ctx == null) {
      _falhar('Terminal não ativado. Ative este terminal antes de operar.');
      return false;
    }
    _cashRegisterId = ctx.cashRegisterId;

    final r = await _caixasFisicos.buscarPorId(ctx.cashRegisterId);
    return r.fold(
      onOk: (pdv) {
        _pdv = pdv;
        _defaultWarehouseId = pdv.defaultWarehouseId;

        // §9: cx_cash_registers.terminal_id é nullable, mas pos_sales exige.
        // Falha AQUI (config) em vez de deixar a venda quebrar no fechamento.
        if (pdv.terminalId.isEmpty) {
          _falhar(
            'Caixa "${pdv.name}" sem terminal configurado. Contate o gestor.',
          );
          return false;
        }
        _terminalId = pdv.terminalId;

        // Cacheia o terminalId para boots offline/futuros.
        if (ctx.terminalId != pdv.terminalId) {
          _terminalCtx.salvar(ctx.comTerminalId(pdv.terminalId));
        }
        if (kDebugMode) {
          debugPrint(
            '[caixa-session] terminal=${pdv.terminalId} caixa=${pdv.code}',
          );
        }
        return true;
      },
      onErr: (f) {
        // Sem rede: usa o terminalId cacheado, se houver.
        if (ctx.terminalId != null && ctx.terminalId!.isNotEmpty) {
          _terminalId = ctx.terminalId;
          return true;
        }
        _falhar('Não foi possível resolver o terminal: ${f.message}');
        return false;
      },
    );
  }

  Future<void> _garantirCaixaAberto() async {
    // 1) Já existe sessão aberta? (evita 409 ao reiniciar)
    final aberta = await _caixa.sessaoAberta(cashRegisterId);
    final reusou = aberta.fold(
      onOk: (s) {
        _caixaSessao = s;
        _set(SessionStatus.pronto);
        debugPrint('[caixa] sessão já aberta: ${s.id}');
        return true;
      },
      onErr: (_) => false, // 404 → abrir
    );
    if (reusou) return;

    // 2) Abrir. openedBy = employeeId (sub).
    final openedBy = _employeeId ?? _authUserId;
    if (openedBy == null) {
      _falhar('Sem operador para abrir o caixa.');
      return;
    }
    final abriu = await _caixa.abrir(
      AbrirCaixaRequest(
        cashRegisterId: cashRegisterId,
        openedBy: openedBy,
        openingFloat: Env.openingFloat,
      ),
    );
    abriu.fold(
      onOk: (s) {
        _caixaSessao = s;
        _set(SessionStatus.pronto);
        debugPrint('[caixa] aberto: ${s.id}');
      },
      onErr: (f) => _falhar('Abrir caixa falhou: ${f.message}'),
    );
  }

  /// Atualiza o semáforo de teto a partir de uma resposta (venda ou movimento).
  ///
  /// **AUSÊNCIA (null) = NÃO atualiza** — nunca zera o alerta (contrato v3
  /// §3.9): um replay pode não recomputar o estado; manter o último conhecido é
  /// o comportamento correto e evita que um retry de rede apague o semáforo.
  void aplicarTeto(CashCeilingStatus? novo) {
    if (novo == null) return;
    _cashCeilingStatus = novo;
    notifyListeners();
  }

  /// Garante que o cx-config esteja resolvido antes de usar [maloteHabilitado].
  ///
  /// - Já carregado nesta sessão → retorna imediato (cache do turno).
  /// - Busca em andamento (pre-warm do boot ou outro open) → aguarda a mesma.
  /// - Desconhecido ou falho → dispara uma nova busca (retry sob demanda).
  ///
  /// Chamado pelo diálogo de sangria no open. Nunca lança: em erro/timeout, o
  /// status vira [CxConfigStatus.falhou] e o chamador decide o fallback.
  Future<void> garantirCxConfig({
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (_cxConfigStatus == CxConfigStatus.carregado) {
      return Future<void>.value();
    }
    final inFlight = _cxConfigInFlight;
    if (inFlight != null) return inFlight;

    final future = _buscarCxConfig(timeout);
    _cxConfigInFlight = future;
    return future;
  }

  Future<void> _buscarCxConfig(Duration timeout) async {
    _cxConfigStatus = CxConfigStatus.carregando;
    notifyListeners();
    try {
      final r = await _caixa.cxConfig().timeout(timeout);
      r.fold(
        onOk: (cfg) {
          _cxConfig = cfg;
          _cxConfigStatus = CxConfigStatus.carregado;
          if (kDebugMode) {
            debugPrint('[cx-config] malote=${cfg.maloteHabilitado}');
          }
        },
        onErr: (f) {
          _cxConfigStatus = CxConfigStatus.falhou;
          debugPrint('[cx-config][erro] ${f.message}');
        },
      );
    } on TimeoutException {
      _cxConfigStatus = CxConfigStatus.falhou;
      debugPrint(
        '[cx-config][timeout] sem resposta em ${timeout.inMilliseconds}ms',
      );
    } catch (e) {
      _cxConfigStatus = CxConfigStatus.falhou;
      debugPrint('[cx-config][erro] $e');
    } finally {
      _cxConfigInFlight = null;
      notifyListeners();
    }
  }

  void _set(SessionStatus s) {
    _status = s;
    _erro = null;
    notifyListeners();
  }

  void _falhar(String msg) {
    _status = SessionStatus.erro;
    _erro = msg;
    debugPrint('[caixa-session][erro] $msg');
    notifyListeners();
  }
}
