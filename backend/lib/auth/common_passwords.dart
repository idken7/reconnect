/// Passwords seen in the most common breach lists (lower-case, length >= 8).
/// Not exhaustive: it blocks the guesses an attacker tries first.
bool isCommonPassword(String lowercasePassword) {
  if (_common.contains(lowercasePassword)) return true;
  // Trailing digits / punctuation on a common word ("password1!") are just as guessable.
  final stripped = lowercasePassword.replaceFirst(RegExp(r'[\d!@#$%^&*._-]{1,4}$'), '');
  return stripped.length >= 5 && _commonBases.contains(stripped);
}

const Set<String> _commonBases = {
  'password', 'passw0rd', 'p@ssword', 'p@ssw0rd', 'qwerty', 'qwertyuiop', 'letmein', 'welcome', 'iloveyou',
  'admin', 'administrator', 'monkey', 'dragon', 'football', 'baseball', 'master', 'sunshine', 'princess',
  'trustno', 'shadow', 'superman', 'batman', 'michael', 'jordan', 'harley', 'ranger', 'jennifer', 'hunter',
  'freedom', 'whatever', 'computer', 'starwars', 'cheese', 'summer', 'winter', 'secret', 'changeme',
};

const Set<String> _common = {
  '12345678', '123456789', '1234567890', '12345678910', '11111111', '22222222', '00000000', '87654321',
  '987654321', '0987654321', '1q2w3e4r', '1q2w3e4r5t', '1qaz2wsx', '1qazxsw2', 'q1w2e3r4', 'q1w2e3r4t5',
  'qwer1234', 'asdf1234', 'zxcv1234', 'qwertyui', 'qwertyuiop', 'asdfghjk', 'asdfghjkl', 'zxcvbnm1',
  'zxcvbnm123', 'qazwsxedc', 'abcd1234', 'abcdefgh', 'abcdefg1', 'abc12345', 'abc123456', 'aaaaaaaa',
  'password', 'password1', 'password12', 'password123', 'password1234', 'password!', 'password1!',
  'password01', 'password2', 'password3', 'passw0rd', 'passw0rd1', 'p@ssword', 'p@ssw0rd', 'p@55w0rd',
  'pa55word', 'pa55w0rd', 'passcode', 'passphrase', 'mypassword', 'mypass123', 'mypassword1', 'newpassword',
  'letmein1', 'letmein123', 'letmein!', 'welcome1', 'welcome12', 'welcome123', 'welcome!', 'welcome01',
  'iloveyou', 'iloveyou1', 'iloveyou2', 'iloveyou123', 'ilovegod', 'ilovejesus', 'iloveu123', 'loveyou1',
  'admin123', 'admin1234', 'administrator', 'adminadmin', 'root1234', 'rootroot', 'toor1234', 'test1234',
  'testtest', 'testing1', 'testing123', 'test12345', 'guest123', 'guest1234', 'default1', 'changeme',
  'changeme1', 'changeme123', 'secret123', 'secret12', 'secretsecret', 'trustno1', 'trustno11',
  'monkey123', 'monkey12', 'dragon123', 'dragon12', 'sunshine', 'sunshine1', 'sunshine123', 'princess',
  'princess1', 'princess123', 'football', 'football1', 'football123', 'baseball', 'baseball1', 'basketball',
  'basketball1', 'soccer123', 'hockey123', 'baseball123', 'superman', 'superman1', 'batman123', 'spiderman',
  'spiderman1', 'starwars', 'starwars1', 'pokemon1', 'pokemon123', 'minecraft', 'minecraft1', 'fortnite1',
  'michael1', 'michael123', 'jordan23', 'jordan123', 'jennifer', 'jessica1', 'ashley123', 'daniel123',
  'matthew1', 'thomas123', 'charlie1', 'charlie123', 'andrew123', 'joshua123', 'robert123', 'nicole123',
  'jasmine1', 'hannah123', 'samantha', 'samantha1', 'abcabc123', 'qwerty12', 'qwerty123', 'qwerty1234',
  'qwerty12345', 'qwerty123456', 'qwertyqwerty', 'qwerty123!', 'qwerty1!', 'qwerty!!', 'asdasd123',
  'asdfasdf', 'asdf12345', 'zaq12wsx', 'zaq1zaq1', 'zaq1xsw2', 'xsw2zaq1', 'mnbvcxz1', 'poiuytre',
  'lkjhgfds', 'trustno1!', 'freedom1', 'freedom123', 'whatever', 'whatever1', 'whatever123', 'computer',
  'computer1', 'computer123', 'internet', 'internet1', 'internet123', 'google123', 'facebook', 'facebook1',
  'facebook123', 'twitter1', 'instagram', 'instagram1', 'youtube1', 'netflix1', 'iphone123', 'android1',
  'android123', 'applepie', 'blink182', 'bubbles1', 'butterfly', 'chocolate', 'chocolate1', 'cheese123',
  'summer123', 'summer2020', 'summer2021', 'summer2022', 'summer2023', 'summer2024', 'summer2025',
  'winter123', 'winter2020', 'winter2021', 'winter2022', 'winter2023', 'winter2024', 'winter2025',
  'spring123', 'autumn123', 'spring2024', 'spring2025', 'fall2024!', 'password2020', 'password2021',
  'password2022', 'password2023', 'password2024', 'password2025', 'welcome2020', 'welcome2021',
  'welcome2022', 'welcome2023', 'welcome2024', 'welcome2025', 'january1', 'february1', 'monday123',
  'master123', 'master1234', 'shadow123', 'shadow12', 'ranger123', 'hunter123', 'hunter12', 'harley123',
  'buster123', 'tigger123', 'tiger123', 'tiger1234', 'killer123', 'killer12', 'soccer12', 'hockey12',
  'jordan12', 'liverpool', 'liverpool1', 'manchester', 'arsenal1', 'chelsea1', 'barcelona', 'realmadrid',
  'yankees1', 'yankees123', 'dallas123', 'lakers123', 'cowboys1', 'steelers1', 'patriots1', 'redskins1',
  'mustang1', 'corvette1', 'ferrari1', 'porsche1', 'mercedes1', 'bmw12345', 'toyota123', 'honda123',
  'nothing1', 'nothing123', 'anything1', 'everything', 'something1', 'forever21', 'forever1', 'loveme123',
  'loveme12', 'lovelove', 'lovelove1', 'iloveme1', 'ihateyou', 'fuckyou1', 'fuckyou123', 'fuckoff1',
  'baby1234', 'babygirl', 'babygirl1', 'angel123', 'angels12', 'sweetie1', 'cutiepie', 'cutiepie1',
  'beautiful', 'beautiful1', 'blessed1', 'blessed123', 'jesus123', 'godisgood', 'godbless1', 'password.',
  'p4ssword', 'p4ssw0rd', 'pass1234', 'pass12345', 'pass123456', 'passpass', 'passpass1', 'access123',
  'access14', 'login123', 'login1234', 'logmein1', 'letmein2', 'open1234', 'opensesame', 'sesame12',
  'entrance', 'security', 'security1', 'secure123', 'private1', 'private123', 'hello123', 'hello1234',
  'helloworld', 'hello12345', 'hellohello', 'goodluck', 'goodluck1', 'goodgood', 'happy123', 'happyday',
  'happy1234', 'lucky123', 'lucky777', 'lucky1234', 'america1', 'america123', 'canada123', 'england1',
  'brooklyn', 'brooklyn1', 'newyork1', 'newyork123', 'austin123', 'chicago1', 'chicago123', 'reconnect',
  'reconnect1', 'reconnect123', 'reconnect!', 'reconnectapp', 'myreconnect',
};
