import 'package:toon_format/toon_format.dart';

void main() {
  final toon = encode({
    'users': [
      {'id': 1, 'name': 'Ada', 'role': 'admin'},
      {'id': 2, 'name': 'Bob', 'role': 'user'},
    ],
  });
  print(toon);
  // users[2]{id,name,role}:
  //   1,Ada,admin
  //   2,Bob,user

  print(decode(toon));
  // {users: [{id: 1.0, name: Ada, role: admin}, {id: 2.0, name: Bob, role: user}]}
}
