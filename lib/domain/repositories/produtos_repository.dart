import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';

/// Contrato do repositório de produtos.
///
/// A implementação real (`ProdutosRepositoryImpl` em `data/`) é quem decide
/// se fala primeiro com o cache local (offline-first) ou com a rede.
/// A camada de apresentação **não sabe** dessa diferença.
abstract interface class ProdutosRepository {
  /// Busca um produto pelo código lido (EAN, SKU interno ou código de balança
  /// com peso embutido).
  ///
  /// Retorna `Err(NotFoundFailure)` se não houver produto cadastrado.
  Future<Result<Produto, Failure>> porBarcode(String codigo);

  /// Busca textual por nome ou SKU parcial. Retorna até [limit] resultados,
  /// ordenados por relevância.
  Future<Result<List<Produto>, Failure>> buscar(String query, {int limit = 8});

  /// Lista categorias disponíveis (modo "Atalhos").
  Future<Result<List<String>, Failure>> categorias();

  /// Produtos de uma categoria, ordenados por nome.
  Future<Result<List<Produto>, Failure>> porCategoria(String categoria);
}
