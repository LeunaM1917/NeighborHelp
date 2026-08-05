import 'package:flutter/material.dart';

/// True while the stream has not produced its first event yet.
///
/// Do not use [AsyncSnapshot.hasData] for nullable types — a `null` payload is
/// valid data but [hasData] stays false, which can pair with replay quirks and
/// leave spinners stuck.
bool isStreamWaiting<T>(AsyncSnapshot<T> snap) {
  if (snap.hasError) return false;
  return snap.connectionState == ConnectionState.waiting;
}
