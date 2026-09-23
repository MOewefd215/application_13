import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/post_job_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/job_history_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/report_problem_screen.dart';
import 'screens/review_screen.dart';
import 'screens/job_map_screen.dart';
import 'screens/location_picker_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StudentProApp());
}

class StudentProApp extends StatelessWidget {
  const StudentProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'มือโปรวัยเรียน',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}

/// Simple index screen so every empty UI page can be opened and
/// reviewed individually. Not part of the real app flow — remove
/// once screens are wired into the actual navigation/router.
class ScreenGallery extends StatelessWidget {
  const ScreenGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final screens = <String, WidgetBuilder>{
      'เข้าสู่ระบบ / สมัครสมาชิก': (_) => const LoginScreen(),
      'หน้าแรก (Home)': (_) => const HomeScreen(),
      'รายละเอียดงาน (Job Detail)': (_) => const JobDetailScreen(),
      'แชท (Chat list)': (_) => const ChatScreen(),
      'บทสนทนา (Conversation)': (_) => const ConversationScreen(),
      'โพสต์งาน (Post Job)': (_) => const PostJobScreen(),
      'โปรไฟล์ (Profile)': (_) => const ProfileScreen(),
      'แจ้งเตือน (Notification)': (_) => const NotificationScreen(),
      'ประวัติการทำงาน (Job History)': (_) => const JobHistoryScreen(),
      'ยืนยันตัวตน (Verification)': (_) => const VerificationScreen(),
      'ร้องเรียน / แจ้งปัญหา (Report)': (_) => const ReportProblemScreen(),
      'รีวิว (Review)': (_) => const ReviewScreen(),
      'แผนที่งาน / ระยะทาง (Job Map)': (_) => const JobMapScreen(
          jobTitle: 'ชื่อประกาศงาน', jobLat: 13.7563, jobLng: 100.5018),
      'เลือกตำแหน่งงาน (Location Picker)': (_) =>
          const LocationPickerScreen(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('มือโปรวัยเรียน — UI Preview')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: screens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final title = screens.keys.elementAt(index);
          final builder = screens.values.elementAt(index);
          return Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: builder)),
            ),
          );
        },
      ),
    );
  }
}
