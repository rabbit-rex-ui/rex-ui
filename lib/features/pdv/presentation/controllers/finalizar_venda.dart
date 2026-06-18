import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_request.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_response.dart';
import 'package:rabbit_pdv/features/pdv/data/vendas_repository.dart';

sealed class FinalizarVendaOutcome {
  const FinalizarVendaOutcome();
}

/// Venda concluída. A UI lê `venda.cashCeilingStatus` para o indicador de teto.
final class VendaConcluida extends FinalizarVendaOutcome {
  const VendaConcluida(this.venda);
  final RegistrarVendaResponse venda;
}

/// 409: teto Imediata estourou na venda anterior — exige sangria (§6.3).
final class CaixaBloqueado extends FinalizarVendaOutcome {
  const CaixaBloqueado(this.mensagem);
  final String mensagem;
}

/// 401: sessão inválida (relevante quando a expiração de token entrar).
final class SessaoExpirada extends FinalizarVendaOutcome {
  const SessaoExpirada();
}

/// 422/400/403/404/5xx/rede: mostrar mensagem; operador corrige e refaz.
final class VendaRejeitada extends FinalizarVendaOutcome {
  const VendaRejeitada(this.failure);
  final Failure failure;
}

Future<FinalizarVendaOutcome> finalizarVenda(
  VendasRepository repo,
  RegistrarVendaRequest req,
) async {
  final result = await repo.registrar(req);
  return switch (result) {
    Ok(:final value) => VendaConcluida(value),
    Err(:final failure) => _classificar(failure),
  };
}

FinalizarVendaOutcome _classificar(Failure f) {
  if (f is NetworkFailure && f.statusCode == 401) {
    return const SessaoExpirada();
  }
  if (f is BusinessRuleFailure && f.code == FailureCodes.caixaBloqueado) {
    return CaixaBloqueado(f.message);
  }
  return VendaRejeitada(f);
}
