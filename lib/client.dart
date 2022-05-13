import 'package:http/http.dart' as http;

abstract class MisfortuneClient {
  Future<bool> spin({required String code, required double speed});
}

class HttpMisfortuneClient implements MisfortuneClient {
  @override
  Future<bool> spin({required String code, required double speed}) async {
    final response = await http.post(Uri.https(
      "api.bembel.party",
      "spin",
      {
        "code": code,
        "speed": speed,
      },
    ));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 409) {
      return false;
    } else {
      throw Exception("Error response ${response.statusCode}");
    }
  }
}
