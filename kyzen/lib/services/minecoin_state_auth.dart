class MinecoinService {
  static final MinecoinService instance = MinecoinService._();
  MinecoinService._();

  int? _minecoinBalance;

  int? get minecoinBalance => _minecoinBalance;
  bool get hasLoadedMinecoinBalance => _minecoinBalance != null;

  void setBalance(int balance) {
    _minecoinBalance = balance;
  }

  void reset() {
    _minecoinBalance = null;
  }
}
