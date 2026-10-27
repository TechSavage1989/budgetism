import 'release_feed.dart';

Future<String> downloadVerifiedRelease(ReleaseInfo release,
    {void Function(double)? onProgress}) async =>
    throw UnsupportedError('Native Windows ZIP updates are not supported on this platform.');
