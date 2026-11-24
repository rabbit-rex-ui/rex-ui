import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Cópia local do XML de cada NFC-e impressa (guia fiscal v2.3 §9.4): a
/// reimpressão funciona sem internet — ex.: a expedição perde a conexão
/// depois da autorização. Cópias com mais de 90 dias são apagadas; o XML legal
/// fica no backend/retaguarda.
///
/// Melhor esforço: falha de disco nunca impede a impressão.
abstract interface class XmlCupomLocal {
  Future<void> salvar(String notaId, String xml);

  /// `null` se não houver cópia (ou não der para ler).
  Future<String?> ler(String notaId);
}

class XmlCupomLocalArquivos implements XmlCupomLocal {
  /// [pastaBase] padrão: a pasta de dados do app (`getApplicationSupportDirectory`).
  /// Injetável nos testes.
  XmlCupomLocalArquivos({Future<Directory> Function()? pastaBase})
    : _pastaBase = pastaBase ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _pastaBase;

  static const _validade = Duration(days: 90);

  @override
  Future<void> salvar(String notaId, String xml) async {
    try {
      final pasta = await _pasta();
      await _arquivo(pasta, notaId).writeAsString(xml, flush: true);
      await _apagarAntigos(pasta);
    } on FileSystemException {
      // Sem cópia local, só não haverá reimpressão offline desta nota.
    }
  }

  @override
  Future<String?> ler(String notaId) async {
    try {
      final arquivo = _arquivo(await _pasta(), notaId);
      return await arquivo.exists() ? await arquivo.readAsString() : null;
    } on FileSystemException {
      return null;
    }
  }

  Future<Directory> _pasta() async {
    final base = await _pastaBase();
    final separador = Platform.pathSeparator;
    final pasta = Directory('${base.path}${separador}fiscal${separador}cupons');
    await pasta.create(recursive: true);
    return pasta;
  }

  /// O id vem do backend (UUID), mas nunca vira caminho sem higienizar.
  File _arquivo(Directory pasta, String notaId) {
    final nome = notaId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${pasta.path}${Platform.pathSeparator}$nome.xml');
  }

  Future<void> _apagarAntigos(Directory pasta) async {
    final limite = DateTime.now().subtract(_validade);
    await for (final item in pasta.list()) {
      if (item is! File) continue;
      try {
        if ((await item.lastModified()).isBefore(limite)) await item.delete();
      } on FileSystemException {
        // Fica para a próxima limpeza.
      }
    }
  }
}
