import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/data/dto/catalog_busca_response.dart';
import 'package:rabbit_pdv/data/dto/catalog_produto_response.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';

/// Catálogo REAL: `porBarcode` resolve via `/catalog/produtos?sku=` (traz o
/// `id` UUID do backend) e `buscar` via `/catalog/produtos?q=` (busca textual,
/// lista pura). Categorias / produtos por categoria ainda usam o [_fallback]
/// (mock) até os endpoints existirem — o delivery não os consome.
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

  @override
  Future<Result<List<Produto>, Failure>> buscar(
    String query, {
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const Ok([]);

    return _api.send<List<Produto>>(
      (dio) => dio.get<dynamic>(
        '/catalog/produtos',
        queryParameters: {'q': q, 'limit': limit},
      ),
      decode: (data) => catalogBuscaListFromJson(data as List<dynamic>),
    );
  }

  // ── ainda no mock (sem endpoint documentado; delivery não usa) ──
  @override
  Future<Result<List<String>, Failure>> categorias() => _fallback.categorias();

  @override
  Future<Result<List<Produto>, Failure>> porCategoria(String categoria) =>
      _fallback.porCategoria(categoria);
}
