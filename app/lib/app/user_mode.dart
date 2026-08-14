enum UserMode { requester, worker }

extension UserModeLabel on UserMode {
  String get actionLabel => switch (this) {
    UserMode.requester => '依頼する',
    UserMode.worker => '作業する',
  };

  String get switchSemanticsLabel => switch (this) {
    UserMode.requester => '現在は依頼者モードです。ワーカーモードに切り替える',
    UserMode.worker => '現在はワーカーモードです。依頼者モードに切り替える',
  };
}
