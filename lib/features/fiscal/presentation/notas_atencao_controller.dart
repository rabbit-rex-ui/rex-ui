import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';

/// Notas que precisam de atenção (guia fiscal v2.3 §6.6, §8.5): presas e que
/// a reconciliação do backend desistiu de resolver sozinha. Vale para notas de
/// qualquer origem (delivery hoje, balcão depois).
///
/// Singleton: o contador do menu "Notas fiscais" e o diálogo leem o mesmo
/// estado. A fila é pequena e muda devagar — atualiza a cada 90 s (o guia
/// pede 1–2 min) e ao abrir o diálogo.
class NotasAtencaoController extends ChangeNotifier {
  NotasAtencaoController(
    this._repo, {
    required bool Function() pausado,
  }) : _pausado = pausado;

  final NotaFiscalRepository _repo;

  /// Ex.: terminal bloqueado — não consulta a API enquanto ninguém olha.
  final bool Function() _pausado;

  static const _intervalo = Duration(seconds: 90);

  /// O painel mostra as mais antigas primeiro; 50 cobre a fila com folga.
  static const _tamanhoPagina = 50;

  List<NotaFiscalResponse> _notas = const [];
  List<NotaFiscalResponse> get notas => _notas;

  /// Total no backend (pode passar do que está em [notas]).
  int _total = 0;
  int get total => _total;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  /// Nota com "Consultar SEFAZ" em andamento.
  String? _consultandoId;
  String? get consultandoId => _consultandoId;

  String? _aviso;
  String? get aviso => _aviso;

  Timer? _timer;
  int _usuarios = 0;

  /// Começa a atualização periódica. Conta os interessados: o timer para só
  /// quando o último chama [parar].
  void iniciar() {
    _usuarios++;
    if (_timer != null) return;
    atualizar();
    _timer = Timer.periodic(_intervalo, (_) => atualizar());
  }

  void parar() {
    if (_usuarios > 0) _usuarios--;
    if (_usuarios > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> atualizar() async {
    if (_carregando || _pausado()) return;
    _carregando = true;
    notifyListeners();

    final r = await _repo.listarAtencao(size: _tamanhoPagina);
    switch (r) {
      case Ok(:final value):
        _notas = List.unmodifiable(value.conteudo);
        _total = value.total;
        _erro = null;
      case Err(:final failure):
        // Mantém a última lista conhecida; só avisa.
        _erro = failure.message;
    }
    _carregando = false;
    notifyListeners();
  }

  /// "Consultar SEFAZ" (§6.3). Resolvida, a nota sai da lista sozinha.
  Future<void> consultar(NotaFiscalResponse nota) async {
    if (_consultandoId != null) return;
    _consultandoId = nota.id;
    _aviso = null;
    notifyListeners();

    final r = await _repo.consultar(nota.id);
    _aviso = switch (r) {
      Ok(:final value) when value.requerAtencao =>
        'A SEFAZ ainda não deu o desfecho. Se persistir, acione o suporte '
            'ou o contador.',
      Ok(:final value) => 'Nota resolvida: ${value.status.label}.',
      Err(:final failure) => _mensagem(failure),
    };
    _consultandoId = null;
    await atualizar();
  }

  void limparAviso() {
    if (_aviso == null) return;
    _aviso = null;
    notifyListeners();
  }

  String _mensagem(Failure f) {
    if (f is NetworkFailure && f.statusCode == 503) {
      return 'Provedor fiscal indisponível. Tente em instantes.';
    }
    if (f is BusinessRuleFailure && FailureCodes.ehFaltaDePermissao(f.code)) {
      return 'Você não tem permissão para consultar a SEFAZ.';
    }
    return f.message;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
