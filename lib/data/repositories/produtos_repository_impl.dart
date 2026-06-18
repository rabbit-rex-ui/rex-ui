import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/data/dto/catalog_produto_response.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';

/// Catálogo REAL no scan: `porBarcode` resolve via /catalog/produtos?sku=,
/// trazendo o `id` UUID do backend. Busca textual e grade de categorias ainda
/// usam o [_fallback] (mock) até os endpoints existirem.
class ProdutosRepositoryImpl implements ProdutosRepository {
  ProdutosRepositoryImpl(this._api, this._fallback);

  final ApiClient _api;
  final ProdutosRepository _fallback;

  @override
  Future<Result<Produto, Failure>> porBarcode(String codigo) async {
    final sku = codigo.trim();
    if (sku.isEmpty) {
      return const Err<Produto, Failure>(ValidationFailure('Código vazio'));
    }

    final res = await _api.send<Produto>(
      (dio) =>
          dio.get<dynamic>('/catalog/produtos', queryParameters: {'sku': sku}),
      decode: (data) => produtoFromCatalogJson(data as Map<String, dynamic>),
    );

    // Mesmas regras de UX do mock: inativo / sem preço viram BusinessRule.
    return switch (res) {
      Ok(:final value) when !value.ativo => const Err<Produto, Failure>(
        BusinessRuleFailure('Produto inativo', code: 'PRODUTO_INATIVO'),
      ),
      Ok(:final value) when !value.temPreco => const Err<Produto, Failure>(
        BusinessRuleFailure('Produto sem preço cadastrado', code: 'SEM_PRECO'),
      ),
      _ => res, // Ok válido, ou Err (404 → NotFoundFailure pelo _mapStatus)
    };
  }

  // ── ainda no mock (sem endpoint documentado) ──
  @override
  Future<Result<List<Produto>, Failure>> buscar(
    String query, {
    int limit = 8,
  }) => _fallback.buscar(query, limit: limit);

  @override
  Future<Result<List<String>, Failure>> categorias() => _fallback.categorias();

  @override
  Future<Result<List<Produto>, Failure>> porCategoria(String categoria) =>
      _fallback.porCategoria(categoria);
}
