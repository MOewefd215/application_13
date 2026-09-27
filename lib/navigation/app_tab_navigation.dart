import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/job_history_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/profile_screen.dart';

/// Opens a main tab while preserving the current page on the back stack.
void navigateToAppTab(
  BuildContext context, {
  required int destinationIndex,
  required int currentIndex,
}) {
  if (destinationIndex == currentIndex) return;

  final Widget page;
  switch (destinationIndex) {
    case 0:
      page = const HomeScreen();
      break;
    case 1:
      page = const JobHistoryScreen();
      break;
    case 2:
      page = const ChatScreen();
      break;
    case 3:
      page = const NotificationScreen();
      break;
    case 4:
      page = const ProfileScreen();
      break;
    default:
      return;
  }

  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
