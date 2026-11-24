import 'dart:io' show HttpDate;

import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/network/relogio_servidor.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_resumo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/modo_emissao.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/faturar_pedido_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

import 'fiscal_fixtures.dart';

void main() {
  group('ModoEmissao (guia v2.2 §4: enum fechado)', () {
    test('valores conhecidos', () {
      expect(ModoEmissao.fromWire('NORMAL'), ModoEmissao.normal);
      expect(
        ModoEmissao.fromWire('CONTINGENCY_OFFLINE'),
        ModoEmissao.contingenciaOffline,
      );
      expect(
        ModoEmissao.fromWire('CONTINGENCY_SVC'),
        ModoEmissao.contingenciaSvc,
      );
    });

    test('desconhecido vira contingência genérica, sem quebrar', () {
      final m = ModoEmissao.fromWire('CONTINGENCY_EPEC');
      expect(m, ModoEmissao.contingenciaDesconhecida);
      expect(m.emContingencia, isTrue);
    });

    test('a nota expõe emContingencia', () {
      final json = notaJson()..['modoEmissao'] = 'CONTINGENCY_SVC';
      expect(NotaFiscalResponse.fromJson(json).emContingencia, isTrue);
    });
  });

  group('NotaFiscalResumo (notaFiscal no pedido, §7.1)', () {
    test('lê o exemplo do guia', () {
      final r = NotaFiscalResumo.fromPedido({
        'pedidoId': 'p1',
        'notaFiscal': {
          'id': 'n1',
          'modelo': 'NFCE',
          'status': 'AUTHORIZED',
          'aptaParaExpedir': true,
          'cancelamentoEmAndamento': false,
          'requerAtencao': false,
        },
      });
      expect(r?.modelo, NotaModelo.nfce);
      expect(r?.status, NotaStatus.autorizada);
      expect(r?.aptaParaExpedir, isTrue);
    });

    test('ausente logo após o faturar → null', () {
      expect(NotaFiscalResumo.fromPedido({'pedidoId': 'p1'}), isNull);
    });
  });

  test('faturar responde 200 com vendaId (§7, passo 4)', () {
    final r = FaturarPedidoResponse.fromJson({
      'pedidoId': 'p1',
      'vendaId': 'v1',
      'status': 'AGUARDANDO_EXPEDICAO',
    });
    expect(r.vendaId, 'v1');
    expect(r.status, PedidoStatus.aguardandoExpedicao);
  });

  group('RelogioServidor (§8.3)', () {
    test('sem resposta, usa o relógio do terminal', () {
      final relogio = RelogioServidor();
      expect(relogio.desvio, Duration.zero);
    });

    test('servidor 10 min adiantado → agora() adiantado ~10 min', () {
      final relogio = RelogioServidor();
      final servidor = DateTime.now().toUtc().add(const Duration(minutes: 10));
      relogio.registrar(HttpDate.format(servidor));
      final diferenca = relogio.agora().difference(DateTime.now());
      expect(diferenca.inSeconds, closeTo(600, 2));
    });

    test('header inválido é ignorado', () {
      final relogio = RelogioServidor()..registrar('não é data');
      expect(relogio.desvio, Duration.zero);
    });
  });
}

