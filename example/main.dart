import 'package:transmission/transmission.dart';

main() async {
  final transmission = Transmission(/*baseUrl: 'http://192.168.1.35:9091/transmission/rpc'*/);
  final torrents = await transmission.getTorrents();
  print(torrents);

  //await transmission.addTorrent(metaInfo: 'test');
  //await transmission.stopTorrents(torrents.map((e) => e.id).toList());
  //await transmission.moveTorrents(torrents.map((e) => e.id).toList(), '/Users/jaumard/Documents');
  /*await transmission.renameTorrent(
    torrents.first.id,
    path: torrents.first.name,
    name: 'Logic Pro X 10.5.1 Patched (macOS)',
  )*/
  ;
  //await transmission.startNowTorrents(torrents.map((e) => e.id).toList());
  //await transmission.startTorrents(torrents.map((e) => e.id).toList());
}
