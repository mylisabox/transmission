# transmission

Dart package to talk to a Transmission torrent instance

## Getting Started

Create an instance of `Transmission`, you can then use it in any data state management you want (bloc, provider, mobx...)

```dart
final transmission = Transmission(
  baseUrl: 'http://192.168.1.35:9091/transmission/rpc',
  enableLog: true,
);
``` 

By default baseUrl uses `http://localhost:9091/transmission/rpc`.

Once you have that you can simply interact with transmission's data like torrents or settings.

## Simple examples

### Getting torrents

```dart
final torrents = await transmission.getTorrents();
print(torrents);
``` 

### Adding torrent

```dart
await transmission.addTorrent(filename: 'https://myUrlMagnet');
``` 

### Start torrents

```dart
final torrents = await transmission.getTorrents();
await transmission.startTorrents([torrents.first.id]);
```

### Stop torrents

```dart
final torrents = await transmission.getTorrents();
await transmission.stopTorrents([torrents.first.id]);
``` 

### Remove torrents

```dart
final torrents = await transmission.getTorrents();
await transmission.removeTorrents([torrents.first.id]);
``` 