import '../models/container_status.dart';

/// A filter to apply to the home list from elsewhere in the app - e.g.
/// tapping a non-zero Summary cell jumps to Home pre-filtered to that
/// status and prefix.
class HomeFilterRequest {
  const HomeFilterRequest({this.status, this.search = ''});

  final ContainerStatus? status;
  final String search;
}
