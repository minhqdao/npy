import 'dart:async';
import 'dart:typed_data';

/// Transforms a stream to emit chunks of the specified [bufferSize]. If [bufferSize] is not provided, the stream will
/// be emitted as chunks of default size.
class ChunkTransformer extends StreamTransformerBase<List<int>, List<int>> {
  /// Creates an instance of a [ChunkTransformer] that transforms a stream to emit chunks of the specified [bufferSize].
  /// If [bufferSize] is not provided, the stream will be emitted as chunks of default size.
  const ChunkTransformer({this.bufferSize});

  /// Size of the chunks emitted by the transformed stream. If not provided, the chunk size of the transformed stream
  /// will equal the chunk size of the untransformed stream.
  final int? bufferSize;

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    if (bufferSize == null) {
      yield* stream;
      return;
    }

    bool hasNotReceivedData = true;
    final buffer = BytesBuilder();
    await for (final chunk in stream) {
      if (hasNotReceivedData && chunk.isNotEmpty) hasNotReceivedData = false;
      buffer.add(chunk);

      while (buffer.length >= bufferSize!) {
        final bytesTaken = buffer.takeBytes();
        yield Uint8List.view(bytesTaken.buffer, 0, bufferSize);
        buffer.add(bytesTaken.sublist(bufferSize!));
      }
    }

    if (buffer.isNotEmpty || hasNotReceivedData) yield buffer.takeBytes();
  }
}
