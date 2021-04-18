import 'package:dio/dio.dart';

const csrfProtectionHeader = 'X-Transmission-Session-Id';

const methodAddTorrent = 'torrent-add';
const methodRemoveTorrent = 'torrent-remove';
const methodRenameTorrent = 'torrent-rename-path';
const methodMoveTorrent = 'torrent-set-location';
const methodGetTorrent = 'torrent-get';
const methodSetTorrent = 'torrent-set';
const methodSetSession = 'session-set';
const methodGetSession = 'session-get';

const methodStartTorrent = 'torrent-start';
const methodStartNowTorrent = 'torrent-start-now';
const methodStopTorrent = 'torrent-stop';
const methodUpdateTorrent = 'torrent-reannounce';
const methodVerifyTorrent = 'torrent-verify';

extension RequestOptionsExtension on RequestOptions {
  Options toOptions() {
    return Options(
      responseType: responseType,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      contentType: contentType,
      extra: extra,
      followRedirects: followRedirects,
      headers: headers,
      listFormat: listFormat,
      maxRedirects: maxRedirects,
      method: method,
      receiveDataWhenStatusError: receiveDataWhenStatusError,
      requestEncoder: requestEncoder,
      responseDecoder: responseDecoder,
      validateStatus: validateStatus,
    );
  }
}

/// Transmission object to interact with a remote instance
/// Documentation about the API at https://github.com/transmission/transmission/blob/master/extras/rpc-spec.txt
class Transmission {
  final bool enableLog;
  final bool proxified;
  final Dio _dio;
  final Dio _tokenDio = Dio();

  Transmission._(this._dio, this.proxified, this.enableLog) {
    _tokenDio.options = _dio.options;
    String? csrfToken;
    if (enableLog) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
    _dio.interceptors.add(
        InterceptorsWrapper(onRequest: (RequestOptions options, handler) async {
      if (csrfToken != null) {
        options.headers[csrfProtectionHeader] = csrfToken;
      }
      handler.next(options);
    }, onError: (DioError error, handler) async {
      if (error.response?.statusCode == 409) {
        _dio.lock();
        final options = error.requestOptions;
        // If the token has been updated, repeat directly.
        if (csrfToken != options.headers[csrfProtectionHeader]) {
          options.headers[csrfProtectionHeader] = csrfToken;
        } else {
          csrfToken = error.response!.headers[csrfProtectionHeader]!.first;
          options.headers[csrfProtectionHeader] = csrfToken;
        }
        //repeat
        try {
          final response = await _tokenDio.request(
            options.path,
            options: options.toOptions(),
            data: options.data,
            cancelToken: options.cancelToken,
            onReceiveProgress: options.onReceiveProgress,
            onSendProgress: options.onSendProgress,
            queryParameters: options.queryParameters,
          );
          _dio.unlock();
          handler.resolve(response);
        } on DioError catch (err) {
          _dio.unlock();
          handler.reject(err);
        } catch (err) {
          print(err);
          _dio.unlock();
          handler.reject(error);
        }
        return;
      }
      handler.next(error);
    }));
  }

  /// Documentation about the API at https://github.com/transmission/transmission/blob/master/extras/rpc-spec.txt
  /// [baseUrl] url of the transmission server instance, default to http://localhost:9091/transmission/rpc
  /// [proxyUrl] url use as a proxy, urls will be added at the end before request, default to null
  /// [enableLog] boolean to show http logs or not
  factory Transmission(
      {String? baseUrl, String? proxyUrl, bool enableLog = false}) {
    baseUrl ??= 'http://localhost:9091/transmission/rpc';
    return Transmission._(
        Dio(BaseOptions(
            baseUrl: proxyUrl == null
                ? baseUrl
                : proxyUrl + Uri.encodeComponent(baseUrl))),
        proxyUrl != null,
        enableLog);
  }

  /// close all connexions
  void dispose() {
    _dio.close();
    _tokenDio.close();
  }

  /// Remove torrents by their given ids
  /// [ids] integer identifier list of the torrents to remove
  /// [deleteLocalData] boolean to also delete local data, default false
  /// Throws [TransmissionException] if errors
  Future<void> removeTorrents(
    List<int> ids, {
    bool deleteLocalData = false,
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodRemoveTorrent, arguments: {
          'ids': ids,
          'delete-local-data': deleteLocalData,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Move torrents by their given ids
  /// [ids] integer identifier list of the torrents to remove
  /// [location] new location to move the torrent
  /// [move] if true, move from previous location otherwise, search "location" for files, default false
  /// Throws [TransmissionException] if errors
  Future<void> moveTorrents(
    List<int> ids,
    String location, {
    bool move = false,
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodMoveTorrent, arguments: {
          'ids': ids,
          'location': location,
          'move': move,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Rename torrent by given id
  /// [id] of the torrent to rename
  /// [name] new name
  /// [path] old name
  /// Throws [TransmissionException] if errors
  Future<void> renameTorrent(
    int id, {
    String? name,
    String? path,
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodRenameTorrent, arguments: {
          'ids': id,
          if (path != null) 'path': path,
          if (name != null) 'name': name,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Add torrent to transmission
  /// [filename] optional filename or URL of the .torrent file
  /// [metaInfo] optional base64-encoded .torrent content
  /// [downloadDir] optional directory where to download the torrent
  /// [cookies] optional pointer to a string of one or more cookies
  /// [paused] optional boolean to paused the torrent when added
  /// Returns [TorrentLight] light torrent info if added successfully
  /// Throws [AddTorrentException] if errors
  Future<TorrentLight> addTorrent({
    String? filename,
    String? metaInfo,
    String? downloadDir,
    String? cookies,
    bool? paused,
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodAddTorrent, arguments: {
          if (filename != null) 'filename': filename,
          if (metaInfo != null) 'metainfo': metaInfo,
          if (downloadDir != null) 'download-dir': downloadDir,
          if (cookies != null) 'cookies': cookies,
          if (paused != null) 'paused': paused,
        }).toJSON());
    final response = _Response.fromJSON(results.data);
    if (response.isSuccess) {
      if (response.arguments!['torrent-duplicate'] != null) {
        throw AddTorrentException._(
            response.copyWith(result: 'Torrent duplicated'),
            TorrentLight._(response.arguments!['torrent-duplicate']));
      } else {
        return TorrentLight._(response.arguments!['torrent-added']);
      }
    } else {
      throw AddTorrentException._(
          response, TorrentLight._(response.arguments!['torrent-duplicate']));
    }
  }

  /// Stop torrents by given ids
  /// [ids] integer identifier list of the torrents to remove
  /// Throws [TransmissionException] if errors
  Future<void> stopTorrents(List<int> ids) async {
    final results = await _dio.post('/',
        data: _Request(methodStopTorrent, arguments: {
          'ids': ids,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Start torrents now by given ids
  /// [ids] integer identifier list of the torrents to remove
  /// Throws [TransmissionException] if errors
  Future<void> startNowTorrents(List<int> ids) async {
    final results = await _dio.post('/',
        data: _Request(methodStartNowTorrent, arguments: {
          'ids': ids,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Start torrents by given ids
  /// [ids] integer identifier list of the torrents to remove
  /// Throws [TransmissionException] if errors
  Future<void> startTorrents(List<int> ids) async {
    final results = await _dio.post('/',
        data: _Request(methodStartTorrent, arguments: {
          'ids': ids,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Verify torrents by given ids
  /// [ids] integer identifier list of the torrents to remove
  /// Throws [TransmissionException] if errors
  Future<void> verifyTorrents(List<int> ids) async {
    final results = await _dio.post('/',
        data: _Request(methodVerifyTorrent, arguments: {
          'ids': ids,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  /// Ask for more peers for torrents by given ids
  /// [ids] integer identifier list of the torrents to remove
  /// Throws [TransmissionException] if errors
  Future<void> askForMorePeers(List<int> ids) async {
    final results = await _dio.post('/',
        data: _Request(methodUpdateTorrent, arguments: {
          'ids': ids,
        }).toJSON());
    _checkResults(_Response.fromJSON(results.data));
  }

  void _checkResults(_Response response) {
    if (!response.isSuccess) {
      throw TransmissionException._(response);
    }
  }

  /// Get recently torrents activity
  /// [fields] list of fields to retrieve
  /// Returns list of [RecentlyActiveTorrent] that contain removed torrent ids or torrents update info
  /// Throws [TransmissionException] if errors
  Future<RecentlyActiveTorrent> getRecentlyActive({
    List<String> fields = const [
      'id',
      'name',
      'eta',
      'queuePosition',
      'downloadDir',
      'isFinished',
      'isStalled',
      'leftUntilDone',
      'metadataPercentComplete',
      'error',
      'errorString',
      'percentDone',
      'totalSize',
      'peersConnected',
      'sizeWhenDone',
      'status',
      'rateDownload',
      'rateUpload',
      'peersGettingFromUs',
      'peersSendingToUs',
    ],
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodGetTorrent, arguments: {
          'fields': fields,
          'ids': 'recently-active',
        }).toJSON());
    final response = _Response.fromJSON(results.data);
    _checkResults(response);
    final torrentsData = response.arguments!['torrents'];
    final torrentsRemoved = response.arguments!['removed'];
    return RecentlyActiveTorrent(
      torrentsData
          .map((data) => Torrent._(data))
          .cast<Torrent>()
          .toList(growable: false),
      torrentsRemoved?.cast<int>(),
    );
  }

  /// Get the list of torrents, fields can be provided to get only needed information
  /// [fields] to retrieve, can be checked at https://github.com/transmission/transmission/blob/master/extras/rpc-spec.txt
  /// Returns list of [Torrent] currently in transmission instance
  /// Throws [TransmissionException] if errors
  Future<List<Torrent>?> getTorrents({
    List<String> fields = const [
      'id',
      'name',
      'eta',
      'queuePosition',
      'downloadDir',
      'isFinished',
      'isStalled',
      'leftUntilDone',
      'metadataPercentComplete',
      'error',
      'errorString',
      'percentDone',
      'totalSize',
      'peersConnected',
      'sizeWhenDone',
      'status',
      'rateDownload',
      'rateUpload',
      'peersGettingFromUs',
      'peersSendingToUs',
    ],
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodGetTorrent, arguments: {
          'fields': fields,
        }).toJSON());
    final response = _Response.fromJSON(results.data);
    _checkResults(response);
    final torrentsData = response.arguments!['torrents'];
    return torrentsData
        .map((data) => Torrent._(data))
        .cast<Torrent>()
        .toList(growable: false);
  }

  /// Get data session, fields can be provided to get only needed information
  /// [fields] to retrieve, can be checked at https://github.com/transmission/transmission/blob/master/extras/rpc-spec.txt
  /// Returns [Map] of the session's data
  /// Throws [TransmissionException] if errors
  Future<Map<String, dynamic>?> getSession({
    List<String> fields = const [
      'alt-speed-enabled',
      'speed-limit-down-enabled',
      'speed-limit-up-enabled',
      'download-dir',
      'speed-limit-down',
      'speed-limit-up',
      'alt-speed-down',
      'alt-speed-up',
      'version',
    ],
  }) async {
    final results = await _dio.post('/',
        data: _Request(methodGetSession, arguments: {
          'fields': fields,
        }).toJSON());
    final response = _Response.fromJSON(results.data);
    _checkResults(response);
    return response.arguments;
  }

  /// Set data session
  /// [fields] to set, can be checked at https://github.com/transmission/transmission/blob/master/extras/rpc-spec.txt
  /// Throws [TransmissionException] if errors
  Future<void> setSession(Map<String, dynamic> fields) async {
    final results = await _dio.post('/',
        data: _Request(methodSetSession, arguments: fields).toJSON());
    final response = _Response.fromJSON(results.data);
    _checkResults(response);
  }
}

class RecentlyActiveTorrent {
  final List<Torrent>? torrents;
  final List<int>? removed;

  RecentlyActiveTorrent(this.torrents, this.removed);

  @override
  String toString() {
    return 'RecentlyActiveTorrent{torrents: $torrents, removed: $removed}';
  }
}

class AddTorrentException extends TransmissionException {
  final TorrentLight torrent;

  AddTorrentException._(_Response cause, this.torrent) : super._(cause);

  @override
  String toString() {
    return 'AddTorrentException($cause, $torrent)';
  }
}

class TransmissionException {
  final _Response cause;

  TransmissionException._(this.cause);

  @override
  String toString() {
    return 'TransmissionException($cause)';
  }
}

class TorrentLight {
  final Map<String, dynamic>? _rawData;

  TorrentLight._(this._rawData);

  int? get id => _rawData!['id'];

  String? get name => _rawData!['name'];

  String? get hash => _rawData!['hashString'];

  @override
  String toString() {
    return 'TorrentLight{_rawData: $_rawData}';
  }
}

class Torrent {
  final Map<String, dynamic> _rawData;

  Torrent._(this._rawData);

  Map<String, dynamic> get rawData => _rawData;

  int? get id => _rawData['id'];

  String? get name => _rawData['name'];

  String? get hash => _rawData['hashString'];

  String? get downloadDir => _rawData['downloadDir'];

  int? get error => _rawData['error'];

  String? get errorString => _rawData['errorString'];

  bool? get isFinished => _rawData['isFinished'];

  bool? get isStalled => _rawData['isStalled'];

  int? get totalSize => _rawData['totalSize'];

  int? get eta => _rawData['eta'];

  int? get status => _rawData['status'];

  String get statusDescription {
    if (error != 0) {
      return 'Error';
    }
    switch (status) {
      case 0:
        return 'Stopped';
      case 1:
        return 'Check waiting';
      case 2:
        return 'Checking';
      case 3:
        return 'Download waiting';
      case 4:
        return 'Downloading';
      case 5:
        return 'Seed waiting';
      case 6:
        return 'Seeding';
    }
    return 'Unkown';
  }

  double? get metadataPercentComplete =>
      _rawData['metadataPercentComplete'] * 100.0;

  int? get sizeWhenDone => _rawData['sizeWhenDone'];

  int? get leftUntilDone => _rawData['leftUntilDone'];

  int? get rateUpload => _rawData['rateUpload'];

  int? get rateDownload => _rawData['rateDownload'];

  String get prettyRateDownload =>
      _prettySize(rateDownload!, decimal: 1) + '/s';

  String get prettyRateUpload => _prettySize(rateUpload!, decimal: 1) + '/s';

  int? get queuePosition => _rawData['queuePosition'];

  double? get percentDone => _rawData['percentDone'] * 100.0;

  bool get isMetadataDownloaded => _rawData['metadataPercentComplete'] == 1;

  int? get peersSendingToUs => _rawData['peersSendingToUs'];

  int? get peersGettingFromUs => _rawData['peersGettingFromUs'];

  int? get peersConnected => _rawData['peersConnected'];

  String get prettyTotalSize {
    return _prettySize(totalSize!);
  }

  String get prettyLeftUntilDone {
    return _prettySize(leftUntilDone!);
  }

  String get prettyCurrentSize {
    return _prettySize(totalSize! - leftUntilDone!);
  }

  String _prettySize(int sizeInOctet, {decimal = 2}) {
    if (sizeInOctet < 1000) {
      return '${sizeInOctet} o';
    } else if (sizeInOctet >= 1000 && sizeInOctet < 1000000) {
      return (sizeInOctet / 1000).toStringAsFixed(decimal) + ' Ko';
    } else if (sizeInOctet >= 1000000 && sizeInOctet < 1000000000) {
      return (sizeInOctet / 1000000).toStringAsFixed(decimal) + ' Mo';
    } else {
      return (sizeInOctet / 1000000000).toStringAsFixed(decimal) + ' Go';
    }
  }

  dynamic operator [](String name) {
    return _rawData[name];
  }

  @override
  String toString() {
    return 'Torrent: $_rawData';
  }
}

class _Request {
  final String method;
  final Map<String, dynamic>? arguments;
  final String? tag;

  _Request(this.method, {this.arguments, this.tag});

  Map<String, dynamic> toJSON() {
    return {
      'method': method,
      if (arguments != null) 'arguments': arguments,
      if (tag != null) 'tag': tag,
    };
  }

  @override
  String toString() {
    return 'Request{method: $method, arguments: $arguments, tag: $tag}';
  }
}

class _Response {
  final String? result;
  final Map<String, dynamic>? arguments;
  final String? tag;

  _Response(this.result, {this.arguments, this.tag});

  factory _Response.fromJSON(Map<String, dynamic> data) {
    return _Response(data['result'],
        arguments: data['arguments'], tag: data['tag']);
  }

  _Response copyWith({String? result}) {
    return _Response(result, arguments: arguments, tag: tag);
  }

  bool get isSuccess => result == 'success';

  @override
  String toString() {
    return 'Response{result: $result, arguments: $arguments, tag: $tag}';
  }
}
