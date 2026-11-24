import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/arquivo_baixado.dart';
import 'package:rabbit_pdv/core/result/result.dart';

/// Abre o DANFE da NF-e (PDF A4) no visualizador padrão do Windows, de onde
/// o operador imprime (Ctrl+P).
///
/// Solução provisória por decisão de produto (2026-11-19): o guia v2.2 §9.5
/// prevê impressão direta com `Printing.directPrintPdf`, adiada para uma
/// próxima etapa. Trocar por impressão silenciosa é trocar só esta
/// implementação. O cupom da NFC-e NÃO passa por aqui: ele é montado no app a
/// partir do XML (§9.2).
abstract interface class ArquivoFiscalLocal {
  /// Grava o DANFE numa pasta temporária do app e o abre no visualizador
  /// padrão. Devolve o caminho do arquivo gravado.
  Future<Result<String, Failure>> abrirDanfe(
    ArquivoBaixado arquivo, {
    required String nomeBase,
  });
}

class ArquivoFiscalLocalSistema implements ArquivoFiscalLocal {
  /// Só abrimos tipos esperados — nada de executar o que o servidor mandar.
  static const _extensoesDanfe = {'application/pdf': 'pdf', 'text/html': 'html'};

  /// O DANFE traz dados do consumidor: não deixamos cópias velhas no disco.
  static const _validadeTemporarios = Duration(days: 1);

  @override
  Future<Result<String, Failure>> abrirDanfe(
    ArquivoBaixado arquivo, {
    required String nomeBase,
  }) async {
    final extensao = _extensoesDanfe[arquivo.mimeType];
    if (extensao == null) {
      return Err(_formatoInesperado('DANFE', arquivo.mimeType));
    }
    try {
      final pasta = await _pastaTemporaria();
      final gravado = await _gravar(pasta, '$nomeBase.$extensao', arquivo);
      await _abrirNoSistema(gravado.path);
      return Ok(gravado.path);
    } on Object catch (e) {
      return Err(StorageFailure('Não foi possível abrir o DANFE.', cause: e));
    }
  }

  Future<Directory> _pastaTemporaria() async {
    final base = await getTemporaryDirectory();
    final pasta = Directory(
      '${base.path}${Platform.pathSeparator}rabbit_pdv_fiscal',
    );
    await pasta.create(recursive: true);
    await _apagarAntigos(pasta);
    return pasta;
  }

  Future<void> _apagarAntigos(Directory pasta) async {
    final limite = DateTime.now().subtract(_validadeTemporarios);
    await for (final item in pasta.list()) {
      if (item is! File) continue;
      try {
        if ((await item.lastModified()).isBefore(limite)) await item.delete();
      } on FileSystemException {
        // Arquivo aberto no visualizador: fica para a próxima limpeza.
      }
    }
  }

  Future<File> _gravar(
    Directory pasta,
    String nome,
    ArquivoBaixado arquivo,
  ) {
    final seguro = nome.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final destino = File('${pasta.path}${Platform.pathSeparator}$seguro');
    return destino.writeAsBytes(arquivo.bytes, flush: true);
  }

  /// Abre com o aplicativo padrão do sistema. Sem shell: o caminho vai como
  /// argumento, nunca interpolado numa linha de comando.
  Future<void> _abrirNoSistema(String caminho) async {
    final comando = switch (Platform.operatingSystem) {
      'windows' => 'explorer.exe',
      'macos' => 'open',
      _ => 'xdg-open',
    };
    await Process.start(
      comando,
      [caminho],
      mode: ProcessStartMode.detached,
    );
  }

  static Failure _formatoInesperado(String oQue, String mimeType) {
    final tipo = mimeType.isEmpty ? 'sem tipo' : mimeType;
    return UnknownFailure(
      'O servidor enviou o $oQue num formato inesperado ($tipo).',
    );
  }
}
