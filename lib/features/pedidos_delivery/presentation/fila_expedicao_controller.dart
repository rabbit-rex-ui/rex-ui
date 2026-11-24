import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_resumo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Fila de expedição (guia fiscal v2.3 §7.1): pedidos AGUARDANDO_EXPEDICAO com
/// a situação da nota numa leitura só. Imprime a nota e libera "Expedir".
///
/// Atualização: a cada 5 s enquanto houver nota em andamento (ou ainda sem
/// nota, logo após o faturar); senão a cada 30 s.
///
/// Impressão automática (só na estação de expedição, ver
/// [ConfiguracaoImpressao.imprimirNaExpedicao]): imprime UMA vez quando a
/// nota de um pedido **fica** autorizada diante deste terminal — ou seja, foi
/// vista em andamento (ou sem nota) e depois autorizada. Notas que já chegam
/// autorizadas ao abrir a fila não saem sozinhas (podem ter sido impressas
/// antes, aqui ou em outro terminal): o operador usa "Imprimir". Só NFC-e: o
/// DANFE da NF-e ainda abre no visualizador do Windows, e abrir janela sozinho
/// atrapalharia.
class FilaExpedicaoController extends ChangeNotifier {
  FilaExpedicaoController({
    required PedidoDeliveryRepository pedidos,
    required ImpressaoFiscal impressao,
    required ConfiguracaoImpressaoStore configuracao,
    required bool Function() pausado,
  }) : _pedidos = pedidos,
       _impressao = impressao,
       _configuracao = configuracao,
       _pausado = pausado;

  final PedidoDeliveryRepository _pedidos;
  final ImpressaoFiscal _impressao;
  final ConfiguracaoImpressaoStore _configuracao;

  /// Ex.: terminal bloqueado — não consulta a API nem imprime.
  final bool Function() _pausado;

  static const _rapido = Duration(seconds: 5);
  static const _lento = Duration(seconds: 30);
  static const _tamanho = 50;

  List<PedidoResumoResponse> _itens = const [];
  List<PedidoResumoResponse> get itens => _itens;

  bool _carregando = true;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  ({String texto, bool erro})? _aviso;
  ({String texto, bool erro})? get aviso => _aviso;

  bool _automatica = false;

  /// Este terminal está configurado como estação de expedição.
  bool get impressaoAutomatica => _automatica;

  /// Pedido com ação (imprimir/expedir) em andamento.
  String? _ocupadoId;
  String? get ocupadoId => _ocupadoId;

  /// Pedidos vistos com a nota ainda não autorizada (ou sem nota).
  final _viuEmAndamento = <String>{};

  /// Notas já impressas por este terminal nesta sessão (auto ou manual).
  final _impressas = <String>{};

  Timer? _timer;
  bool _descartado = false;

  /// Uma atualização por vez; pedida durante outra, roda logo depois.
  bool _atualizando = false;
  bool _atualizarDeNovo = false;

  bool foiImpressa(NotaFiscalResumo nota) => _impressas.contains(nota.id);

  void iniciar() => atualizar();

  Future<void> atualizar() async {
    if (_atualizando) {
      _atualizarDeNovo = true;
      return;
    }
    _timer?.cancel();
    if (_descartado) return;
    if (_pausado()) {
      _agendar(_lento);
      return;
    }
    _atualizando = true;
    try {
      await _atualizarAgora();
    } finally {
      _atualizando = false;
    }
    if (_atualizarDeNovo) {
      _atualizarDeNovo = false;
      await atualizar();
    }
  }

  Future<void> _atualizarAgora() async {

    final config = await _configuracao.ler();
    final r = await _pedidos.listar(
      status: PedidoStatus.aguardandoExpedicao,
      size: _tamanho,
    );
    if (_descartado) return;

    _automatica = config.imprimirNaExpedicao;
    switch (r) {
      case Ok(:final value):
        _itens = List.unmodifiable(value.conteudo);
        _erro = null;
      case Err(:final failure):
        _erro = failure.message; // mantém a última lista conhecida
    }
    _carregando = false;
    notifyListeners();

    if (r case Ok()) await _imprimirAutorizadasAgora();
    _agendar(_algumEmAndamento() ? _rapido : _lento);
  }

  /// Impressão manual (ou reimpressão — a cópia local do XML cobre a falta
  /// de internet).
  Future<void> imprimir(PedidoResumoResponse pedido) async {
    final nota = pedido.notaFiscal;
    if (nota == null || _ocupadoId != null) return;
    _ocupar(pedido.pedidoId);
    _aviso = await _imprimir(nota);
    _liberar();
  }

  /// POST /pdv/pedidos/{id}/expedir. O backend revalida a nota (409).
  Future<void> expedir(PedidoResumoResponse pedido) async {
    if (_ocupadoId != null) return;
    _ocupar(pedido.pedidoId);
    final r = await _pedidos.expedir(pedido.pedidoId);
    _aviso = switch (r) {
      Ok() => (texto: 'Pedido #${pedido.orderNumber} expedido.', erro: false),
      Err(:final failure) => (texto: _mensagemExpedir(failure), erro: true),
    };
    _liberar();
    await atualizar();
  }

  void limparAviso() {
    if (_aviso == null) return;
    _aviso = null;
    notifyListeners();
  }

  // ── Regras ──

  bool _algumEmAndamento() => _itens.any((p) {
    final nota = p.notaFiscal;
    return nota == null || nota.status.emProcessamento;
  });

  /// Registra quem está em andamento e imprime quem acabou de autorizar.
  Future<void> _imprimirAutorizadasAgora() async {
    final prontas = <NotaFiscalResumo>[];
    for (final p in _itens) {
      final nota = p.notaFiscal;
      if (nota == null || nota.status.emProcessamento) {
        _viuEmAndamento.add(p.pedidoId);
      } else if (_viuEmAndamento.remove(p.pedidoId) &&
          _imprimivel(nota) &&
          nota.modelo == NotaModelo.nfce &&
          !_impressas.contains(nota.id)) {
        prontas.add(nota);
      }
    }
    if (!_automatica || prontas.isEmpty) return;

    for (final nota in prontas) {
      if (_descartado || _pausado()) return;
      final aviso = await _imprimir(nota);
      // Só incomoda o operador se der errado.
      if (aviso.erro) _aviso = aviso;
    }
    notifyListeners();
  }

  Future<({String texto, bool erro})> _imprimir(NotaFiscalResumo nota) async {
    final r = await _impressao.imprimir(
      notaId: nota.id,
      modelo: nota.modelo,
      status: nota.status,
      cancelamentoEmAndamento: nota.cancelamentoEmAndamento,
    );
    if (r case Ok()) _impressas.add(nota.id);
    return r.fold<({String texto, bool erro})>(
      onOk: (texto) => (texto: texto, erro: false),
      onErr: (f) => (texto: f.message, erro: true),
    );
  }

  static bool _imprimivel(NotaFiscalResumo nota) =>
      nota.status == NotaStatus.autorizada && !nota.cancelamentoEmAndamento;

  static String _mensagemExpedir(Failure f) {
    if (f is BusinessRuleFailure) {
      if (f.code == FailureCodes.pedidoExpedicaoBloqueada) {
        return 'A nota ainda não permite expedir (em autorização, rejeitada '
            'ou com cancelamento em andamento).';
      }
      if (FailureCodes.ehFaltaDePermissao(f.code)) {
        return 'Você não tem permissão para expedir.';
      }
      if (f.code == FailureCodes.pedidoTransicaoInvalida) {
        return 'O pedido mudou de estado. A fila foi atualizada.';
      }
    }
    return f.message;
  }

  void _ocupar(String pedidoId) {
    _ocupadoId = pedidoId;
    _aviso = null;
    notifyListeners();
  }

  void _liberar() {
    _ocupadoId = null;
    if (!_descartado) notifyListeners();
  }

  void _agendar(Duration espera) {
    if (_descartado) return;
    _timer = Timer(espera, atualizar);
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    super.dispose();
  }
}
