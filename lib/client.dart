import 'package:http/http.dart' as http;

abstract class MisfortuneClient {
  Future<bool> spin();
}

class HttpMisfortuneClient implements MisfortuneClient {
  static const _kBaseUrl = "https://api.bembel.party";

  @override
  Future<bool> spin() async {
    final response = await http.post(Uri.parse("$_kBaseUrl/spin"));
    if (response.statusCode == 204) {
      return true;
    } else if (response.statusCode == 409) {
      return false;
    } else {
      throw Exception("Error response ${response.statusCode}");
    }
  }
}
