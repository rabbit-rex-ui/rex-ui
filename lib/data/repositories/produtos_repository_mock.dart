import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';

/// Implementação **in-memory** para desenvolvimento e testes.
///
/// Quando o backend estiver pronto, substituir por `ProdutosRepositoryImpl`
/// que combina cache local + API, mantendo este como fallback de testes.
class ProdutosRepositoryMock implements ProdutosRepository {
  static const _latencia = Duration(milliseconds: 80);

  static final List<Produto> _catalogo = [
    // ---- Hortifruti ----
    const Produto(
      id: 'mock-2000000000017',
      sku: '2000000000017',
      barcode: '2000000000017',
      nome: 'Banana Prata',
      categoria: 'Hortifruti',
      preco: 6.49,
      un: UnidadeMedida.kg,
      estoque: 42,
    ),
    const Produto(
      id: 'mock-2000000000024',
      sku: '2000000000024',
      barcode: '2000000000024',
      nome: 'Maçã Gala',
      categoria: 'Hortifruti',
      preco: 9.90,
      un: UnidadeMedida.kg,
      estoque: 28,
    ),
    const Produto(
      id: 'mock-2000000000031',
      sku: '2000000000031',
      barcode: '2000000000031',
      nome: 'Tomate Italiano',
      categoria: 'Hortifruti',
      preco: 7.79,
      un: UnidadeMedida.kg,
      estoque: 15,
    ),
    const Produto(
      id: 'mock-2000000000048',
      sku: '2000000000048',
      barcode: '2000000000048',
      nome: 'Alface Crespa',
      categoria: 'Hortifruti',
      preco: 3.49,
      un: UnidadeMedida.un,
      estoque: 22,
    ),

    // ---- Padaria ----
    const Produto(
      id: 'mock-7891000100103',
      sku: '7891000100103',
      barcode: '7891000100103',
      nome: 'Pão Francês',
      categoria: 'Padaria',
      preco: 18.90,
      un: UnidadeMedida.kg,
      estoque: 12,
    ),
    const Produto(
      id: 'mock-7891000100110',
      sku: '7891000100110',
      barcode: '7891000100110',
      nome: 'Pão de Forma Integral',
      categoria: 'Padaria',
      preco: 8.49,
      un: UnidadeMedida.un,
      estoque: 9,
    ),
    const Produto(
      id: 'mock-7891000100127',
      sku: '7891000100127',
      barcode: '7891000100127',
      nome: 'Croissant',
      categoria: 'Padaria',
      preco: 4.50,
      un: UnidadeMedida.un,
      estoque: 6,
    ),

    // ---- Mercearia ----
    const Produto(
      id: 'mock-7891000244104',
      sku: '7891000244104',
      barcode: '7891000244104',
      nome: 'Arroz Branco T1 5kg',
      categoria: 'Mercearia',
      preco: 27.90,
      un: UnidadeMedida.un,
      estoque: 35,
    ),
    const Produto(
      id: 'mock-7891000244111',
      sku: '7891000244111',
      barcode: '7891000244111',
      nome: 'Feijão Carioca 1kg',
      categoria: 'Mercearia',
      preco: 9.49,
      un: UnidadeMedida.un,
      estoque: 41,
    ),
    const Produto(
      id: 'mock-7891000244128',
      sku: '7891000244128',
      barcode: '7891000244128',
      nome: 'Óleo de Soja 900ml',
      categoria: 'Mercearia',
      preco: 6.79,
      un: UnidadeMedida.un,
      estoque: 53,
    ),
    const Produto(
      id: 'mock-7891000244135',
      sku: '7891000244135',
      barcode: '7891000244135',
      nome: 'Açúcar Refinado 1kg',
      categoria: 'Mercearia',
      preco: 5.20,
      un: UnidadeMedida.un,
      estoque: 28,
    ),

    // ---- Refrigerados ----
    const Produto(
      id: 'mock-7891000311004',
      sku: '7891000311004',
      barcode: '7891000311004',
      nome: 'Leite Integral 1L',
      categoria: 'Refrigerados',
      preco: 5.99,
      un: UnidadeMedida.un,
      estoque: 64,
    ),
    const Produto(
      id: 'mock-7891000311011',
      sku: '7891000311011',
      barcode: '7891000311011',
      nome: 'Iogurte Natural 170g',
      categoria: 'Refrigerados',
      preco: 3.20,
      un: UnidadeMedida.un,
      estoque: 33,
    ),

    // ---- Bebidas ----
    const Produto(
      id: 'mock-7891000421000',
      sku: '7891000421000',
      barcode: '7891000421000',
      nome: 'Refrigerante Cola 2L',
      categoria: 'Bebidas',
      preco: 9.99,
      un: UnidadeMedida.un,
      estoque: 47,
    ),
    const Produto(
      id: 'mock-7891000421017',
      sku: '7891000421017',
      barcode: '7891000421017',
      nome: 'Água Mineral 500ml',
      categoria: 'Bebidas',
      preco: 2.49,
      un: UnidadeMedida.un,
      estoque: 88,
    ),
  ];

  @override
  Future<Result<Produto, Failure>> porBarcode(String codigo) async {
    await Future<void>.delayed(_latencia);
    final c = codigo.trim();
    if (c.isEmpty) {
      return const Err(ValidationFailure('Código vazio'));
    }
    final achado = _catalogo.where((p) => p.barcode == c).firstOrNull;
    if (achado == null) {
      return Err(NotFoundFailure('Produto não cadastrado: $c'));
    }
    if (!achado.ativo) {
      return const Err(
        BusinessRuleFailure('Produto inativo', code: 'PRODUTO_INATIVO'),
      );
    }
    if (!achado.temPreco) {
      return const Err(
        BusinessRuleFailure('Produto sem preço cadastrado', code: 'SEM_PRECO'),
      );
    }
    return Ok(achado);
  }

  @override
  Future<Result<List<Produto>, Failure>> buscar(
    String query, {
    int limit = 8,
  }) async {
    await Future<void>.delayed(_latencia);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Ok([]);

    final tudo = _catalogo.where((p) {
      return p.nome.toLowerCase().contains(q) ||
          p.sku.contains(q) ||
          p.categoria.toLowerCase().contains(q);
    }).toList();

    tudo.sort((a, b) {
      final aPref = a.nome.toLowerCase().startsWith(q) ? 0 : 1;
      final bPref = b.nome.toLowerCase().startsWith(q) ? 0 : 1;
      if (aPref != bPref) return aPref - bPref;
      return a.nome.compareTo(b.nome);
    });

    return Ok(tudo.take(limit).toList());
  }

  @override
  Future<Result<List<String>, Failure>> categorias() async {
    await Future<void>.delayed(_latencia);
    final cats = _catalogo.map((p) => p.categoria).toSet().toList()..sort();
    return Ok(cats);
  }

  @override
  Future<Result<List<Produto>, Failure>> porCategoria(String categoria) async {
    await Future<void>.delayed(_latencia);
    final lista = _catalogo.where((p) => p.categoria == categoria).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    return Ok(lista);
  }
}
