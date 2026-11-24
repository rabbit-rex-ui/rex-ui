import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/cancelar_nota_request.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/domain/justificativa_cancelamento.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';

/// Ação do painel em execução. Uma por vez.
enum NotaAcao { emitir, cancelar, consultar, imprimir, mockDesfecho }

/// Mensagem ao operador depois de uma ação.
class AvisoFiscal {
  const AvisoFiscal.erro(
    this.texto, {
    this.orientacao,
    this.configurarImpressora = false,
  }) : erro = true;
  const AvisoFiscal.info(this.texto)
    : erro = false,
      orientacao = null,
      configurarImpressora = false;

  final String texto;

  /// O que fazer a seguir (ex.: "emita nota de devolução"). Vem do backend nas
  /// recusas de cancelamento (guia fiscal §6.2).
  final String? orientacao;
  final bool erro;

  /// O terminal não tem térmica configurada: a tela oferece o atalho para o
  /// diálogo "Impressoras".
  final bool configurarImpressora;
}

/// Estado das notas fiscais de UMA venda (guia fiscal v2.0). Descartável: um
/// por painel aberto.
///
/// O backend é a fonte da verdade. Depois de qualquer falha de ação, a lista é
/// recarregada — o estado na tela nunca fica "adivinhado".
class NotasFiscaisController extends ChangeNotifier {
  NotasFiscaisController({
    required NotaFiscalRepository repo,
    required ImpressaoFiscal impressao,
    required this.vendaId,
  }) : _repo = repo,
       _impressao = impressao;

  final NotaFiscalRepository _repo;
  final ImpressaoFiscal _impressao;
  final String vendaId;

  // ── Polling (guia §10): 1 s, 2 s, 3 s, 5 s, depois a cada 10 s, por ~60 s ──
  static const _intervalosPolling = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];
  static const _intervaloPollingMaximo = Duration(seconds: 10);
  static const _janelaPolling = Duration(seconds: 60);

  // ── Logo após o faturar a lista pode vir vazia: até 3× com 500 ms (guia
  //    v2.2 §7 / respostas do backend §3) ──
  static const _tentativasSeVazia = 3;
  static const _esperaSeVazia = Duration(milliseconds: 500);

  // ── Estado ──
  List<NotaFiscalResponse> _notas = const [];

  /// Notas da venda, mais recente primeiro (no máximo uma autorizada).
  List<NotaFiscalResponse> get notas => _notas;

  /// A nota que importa agora: a mais recente.
  NotaFiscalResponse? get notaAtual => _notas.isEmpty ? null : _notas.first;

  /// Notas anteriores (rejeitadas/canceladas), para o histórico.
  List<NotaFiscalResponse> get historico =>
      _notas.length <= 1 ? const [] : _notas.sublist(1);

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erroCarga;
  String? get erroCarga => _erroCarga;

  NotaAcao? _acaoEmExecucao;
  NotaAcao? get acaoEmExecucao => _acaoEmExecucao;
  bool get ocupado => _acaoEmExecucao != null;

  AvisoFiscal? _aviso;
  AvisoFiscal? get aviso => _aviso;

  /// O polling ativo terminou sem desfecho (guia §10): a tela avisa que o
  /// operador pode sair e oferece "Consultar SEFAZ". O backend segue tentando.
  bool _aguardandoEmSegundoPlano = false;
  bool get aguardandoEmSegundoPlano => _aguardandoEmSegundoPlano;

  /// Última justificativa enviada — preenche o "Tentar de novo" do
  /// cancelamento sem resposta (repetir é seguro: o cancelamento é
  /// idempotente).
  String? _ultimaJustificativa;
  String? get ultimaJustificativa => _ultimaJustificativa;

  /// Pode pedir uma nova emissão: a lista carregou e nenhuma nota ocupa a
  /// venda (PENDING/SENT/AUTHORIZED). O backend recusa reemitir sobre nota
  /// presa de propósito (guia §8.5).
  bool get podeEmitir =>
      !_carregando &&
      _erroCarga == null &&
      !_notas.any((n) => n.status.ativa);

  // ── Cenários do mock (só usados em debug) ──
  String? _cenarioEmissao;
  String? get cenarioEmissao => _cenarioEmissao;
  set cenarioEmissao(String? valor) {
    _cenarioEmissao = valor;
    notifyListeners();
  }

  String? _cenarioCancelamento;
  String? get cenarioCancelamento => _cenarioCancelamento;
  set cenarioCancelamento(String? valor) {
    _cenarioCancelamento = valor;
    notifyListeners();
  }

  // ── Infra do polling ──
  Timer? _timer;
  int _tentativaPolling = 0;
  DateTime _inicioPolling = DateTime.now();

  /// Incrementa a cada parada: uma resposta de polling de uma geração antiga
  /// é descartada (evita sobrescrever estado novo com resposta velha).
  int _geracaoPolling = 0;
  bool _descartado = false;

  // ─────────────────────────── Carga ───────────────────────────

  Future<void> carregar() async {
    _carregando = true;
    _erroCarga = null;
    notifyListeners();

    final falha = await _recarregarLista(insistirSeVazia: true);
    if (_descartado) return;

    _carregando = false;
    _erroCarga = falha?.message;
    notifyListeners();
    _reiniciarPolling();
  }

  /// Busca a lista e substitui o estado. Devolve a falha, se houver. Não
  /// notifica — quem chama decide.
  Future<Failure?> _recarregarLista({bool insistirSeVazia = false}) async {
    var tentativasRestantes = insistirSeVazia ? _tentativasSeVazia : 0;
    while (true) {
      final result = await _repo.listarPorVenda(vendaId);
      if (_descartado) return null;

      final falha = result.fold<Failure?>(
        onOk: (notas) {
          _notas = List.unmodifiable(notas);
          return null;
        },
        onErr: (f) => f,
      );
      if (falha != null) return falha;
      if (_notas.isNotEmpty || tentativasRestantes <= 0) return null;

      tentativasRestantes--;
      await Future<void>.delayed(_esperaSeVazia);
      if (_descartado) return null;
    }
  }

  // ─────────────────────────── Ações ───────────────────────────

  /// Emissão manual / reemissão (guia §6.1). Nasce uma NOVA nota; as
  /// rejeitadas/canceladas ficam no histórico.
  Future<void> emitir() {
    return _executar(NotaAcao.emitir, () async {
      final result = await _repo.emitir(vendaId, cenarioMock: _cenarioEmissao);
      switch (result) {
        case Ok(:final value):
          _substituir(value);
          _reiniciarPolling();
          return null;
        case Err(:final failure):
          return _aposFalha(failure, NotaAcao.emitir);
      }
    });
  }

  /// Cancela a nota atual (guia §6.2, §8.3). Também é o "Tentar de novo" do
  /// cancelamento sem resposta (§8.4).
  Future<void> cancelar(String justificativa) async {
    final nota = notaAtual;
    if (nota == null) return;

    final texto = justificativa.trim();
    final invalida = JustificativaCancelamento.validar(texto);
    if (invalida != null) {
      _aviso = AvisoFiscal.erro(invalida);
      notifyListeners();
      return;
    }
    _ultimaJustificativa = texto;

    await _executar(NotaAcao.cancelar, () async {
      final result = await _repo.cancelar(
        nota.id,
        CancelarNotaRequest(justificativa: texto),
        cenarioMock: _cenarioCancelamento,
      );
      switch (result) {
        case Ok(:final value):
          _substituir(value);
          _reiniciarPolling();
          return const AvisoFiscal.info('Nota cancelada na SEFAZ.');
        case Err(:final failure):
          return _aposFalha(failure, NotaAcao.cancelar);
      }
    });
  }

  /// "Consultar SEFAZ" (guia §6.3): para nota presa ou cancelamento em
  /// andamento.
  Future<void> consultarSefaz() async {
    final nota = notaAtual;
    if (nota == null) return;

    await _executar(NotaAcao.consultar, () async {
      final result = await _repo.consultar(nota.id);
      switch (result) {
        case Ok(:final value):
          _substituir(value);
          _reiniciarPolling();
          return value.precisaAcompanhar
              ? const AvisoFiscal.info(
                  'A SEFAZ ainda não deu o desfecho. O sistema continua '
                  'consultando sozinho.',
                )
              : null;
        case Err(:final failure):
          return _aposFalha(failure, NotaAcao.consultar);
      }
    });
  }

  /// Imprime para o cliente (ver [ImpressaoFiscal]): NFC-e → cupom na
  /// térmica; NF-e → DANFE. Só nota autorizada e sem cancelamento em
  /// andamento (guia v2.3 §9.4).
  Future<void> imprimir(NotaFiscalResponse nota) {
    return _executar(NotaAcao.imprimir, () async {
      final impresso = await _impressao.imprimir(
        notaId: nota.id,
        modelo: nota.modelo,
        status: nota.status,
        cancelamentoEmAndamento: nota.cancelamentoEmAndamento,
      );
      return impresso.fold<AvisoFiscal>(
        onOk: AvisoFiscal.info,
        onErr: (f) => _avisoDe(f, NotaAcao.imprimir),
      );
    });
  }

  /// Só modo mock: "SEFAZ terminou" para uma nota SENT (guia §11).
  Future<void> mockDesfecho(String cenario) async {
    final nota = notaAtual;
    if (nota == null) return;

    await _executar(NotaAcao.mockDesfecho, () async {
      final result = await _repo.mockDesfecho(nota.id, cenario);
      final falha = result.fold<Failure?>(onOk: (_) => null, onErr: (f) => f);
      await _recarregarLista();
      _reiniciarPolling();
      return falha == null ? null : _avisoDe(falha, NotaAcao.mockDesfecho);
    });
  }

  /// Mensagem informativa disparada pela tela (ex.: "Chave copiada").
  void informar(String texto) {
    _aviso = AvisoFiscal.info(texto);
    notifyListeners();
  }

  void limparAviso() {
    if (_aviso == null) return;
    _aviso = null;
    notifyListeners();
  }

  /// Núcleo das ações: uma por vez, limpa o aviso anterior e publica o novo.
  Future<void> _executar(
    NotaAcao acao,
    Future<AvisoFiscal?> Function() corpo,
  ) async {
    if (ocupado || _descartado) return;

    _acaoEmExecucao = acao;
    _aviso = null;
    notifyListeners();

    final aviso = await corpo();
    if (_descartado) return;

    _acaoEmExecucao = null;
    _aviso = aviso;
    notifyListeners();
  }

  /// Depois de uma falha, ressincroniza com o backend antes de avisar.
  Future<AvisoFiscal> _aposFalha(Failure f, NotaAcao acao) async {
    await _recarregarLista();
    _reiniciarPolling();
    return _avisoDe(f, acao);
  }

  void _substituir(NotaFiscalResponse nota) {
    final copia = [..._notas];
    final i = copia.indexWhere((n) => n.id == nota.id);
    if (i < 0) {
      copia.insert(0, nota); // nota nova é a mais recente
    } else {
      copia[i] = nota;
    }
    _notas = List.unmodifiable(copia);
  }

  // ─────────────────────────── Erros ───────────────────────────

  /// Decide a mensagem pelo `code` (sufixo do `type`), nunca pelo texto
  /// (guia §3).
  AvisoFiscal _avisoDe(Failure f, NotaAcao acao) {
    if (f is NetworkFailure) return _avisoDeRede(f, acao);
    if (f is! BusinessRuleFailure) return AvisoFiscal.erro(f.message);

    switch (f.code) {
      case FailureCodes.impressoraNaoConfigurada:
        return AvisoFiscal.erro(f.message, configurarImpressora: true);
      case FailureCodes.acessoNegado:
      case FailureCodes.semPermissao:
        return const AvisoFiscal.erro('Você não tem permissão para esta ação.');
      case FailureCodes.notaFiscalAtivaExistente:
        return const AvisoFiscal.erro(
          'Já existe uma nota em andamento ou autorizada para esta venda. '
          'A lista foi atualizada.',
        );
      case FailureCodes.vendaSemPedidoDeNota:
        return const AvisoFiscal.erro('Esta venda não pediu nota fiscal.');
      case FailureCodes.configuracaoFiscalAusente:
        return const AvisoFiscal.erro(
          'A loja está sem configuração fiscal. Configure os dados fiscais '
          'da loja.',
        );
      case FailureCodes.notaNaoCancelavel:
        return const AvisoFiscal.erro(
          'Só nota autorizada pode ser cancelada. A lista foi atualizada.',
        );
      case FailureCodes.transicaoNotaInvalida:
        return const AvisoFiscal.erro(
          'A nota mudou de estado. A lista foi atualizada.',
        );
      default:
        // Inclui as recusas de cancelamento (prazo expirado, mercadoria já
        // circulou, rejeitado pela SEFAZ): a nota segue autorizada e o
        // backend diz o que fazer em `orientacao`.
        final sufixo = acao == NotaAcao.cancelar
            ? ' A nota continua autorizada.'
            : '';
        return AvisoFiscal.erro(
          '${f.message}$sufixo',
          orientacao: f.detailText('orientacao'),
        );
    }
  }

  AvisoFiscal _avisoDeRede(NetworkFailure f, NotaAcao acao) {
    final provedorFora = f.statusCode == 503;
    if (acao == NotaAcao.cancelar) {
      // Resultado incerto (guia §8.4): não sabemos se a SEFAZ cancelou.
      return provedorFora
          ? const AvisoFiscal.erro(
              'A SEFAZ não respondeu ao cancelamento. Ele ficou em andamento '
              'e a nota não pode ser expedida até a confirmação. Tente de '
              'novo (é seguro repetir) ou consulte a SEFAZ.',
            )
          : AvisoFiscal.erro(
              '${f.message} Não dá para saber se o cancelamento chegou: '
              'confira a nota e, se preciso, tente de novo (é seguro '
              'repetir).',
            );
    }
    if (provedorFora) {
      return const AvisoFiscal.erro(
        'Provedor fiscal indisponível. Tente em instantes.',
      );
    }
    return AvisoFiscal.erro(f.message);
  }

  // ─────────────────────────── Polling ───────────────────────────

  /// (Re)inicia o acompanhamento se a nota atual ainda espera a SEFAZ.
  void _reiniciarPolling() {
    _pararPolling();
    _aguardandoEmSegundoPlano = false;
    final nota = notaAtual;
    if (_descartado || nota == null || !nota.precisaAcompanhar) return;

    _inicioPolling = DateTime.now();
    _tentativaPolling = 0;
    _agendarConsulta(_geracaoPolling);
  }

  void _pararPolling() {
    _timer?.cancel();
    _timer = null;
    _geracaoPolling++;
  }

  void _agendarConsulta(int geracao) {
    if (DateTime.now().difference(_inicioPolling) >= _janelaPolling) {
      _aguardandoEmSegundoPlano = true;
      notifyListeners();
      return;
    }
    final espera = _tentativaPolling < _intervalosPolling.length
        ? _intervalosPolling[_tentativaPolling]
        : _intervaloPollingMaximo;
    _tentativaPolling++;
    _timer = Timer(espera, () => _consultarParaPolling(geracao));
  }

  /// Uma requisição por vez: a próxima só é agendada depois desta responder.
  Future<void> _consultarParaPolling(int geracao) async {
    final nota = notaAtual;
    if (nota == null) return;

    final result = await _repo.buscar(nota.id);
    if (_descartado || geracao != _geracaoPolling) return;

    // Falha no polling é transitória: ignora e tenta no próximo ciclo.
    result.fold<void>(onOk: _substituir, onErr: (_) {});
    notifyListeners();

    if (notaAtual?.precisaAcompanhar ?? false) {
      _agendarConsulta(geracao);
    } else {
      _timer = null;
    }
  }

  @override
  void dispose() {
    _descartado = true;
    _pararPolling();
    super.dispose();
  }
}
