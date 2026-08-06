import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'presigned_upload_client.dart';

part 'presigned_upload_client_provider.g.dart';

/// The app-wide [PresignedUploadClient] used to PUT avatar bytes directly to
/// R2. Separate from the `apiClient` provider: no Firebase bearer, no
/// interceptors.
@Riverpod(keepAlive: true)
PresignedUploadClient presignedUploadClient(Ref ref) {
  return PresignedUploadClient();
}
