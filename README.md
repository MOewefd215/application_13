# มือโปรวัยเรียน — UI Screens (เปล่า/ไม่มีข้อมูล)

หน้าจอ UI ทั้งหมดตามภาพตัวอย่างในเอกสาร ทำเป็น Flutter widgets ล้วน ๆ
ไม่มีการเชื่อมต่อ Firebase หรือข้อมูลจริง (empty states เท่านั้น)

## วิธีเปิดดู
```
flutter pub get
flutter run
```
แอปจะเปิดหน้า "UI Preview" ที่มีรายการหน้าจอทั้งหมด กดเข้าไปดูทีละหน้าได้

## หน้าที่ทำไว้ (ตรงกับภาพในเอกสาร)
1. `login_screen.dart` — เข้าสู่ระบบ / สมัครสมาชิก
2. `home_screen.dart` — หน้าแรก
3. `job_detail_screen.dart` — รายละเอียดงาน
4. `chat_screen.dart` — รายการแชท + หน้าสนทนา (ConversationScreen)
5. `post_job_screen.dart` — โพสต์งาน
6. `profile_screen.dart` — โปรไฟล์
7. `wallet_screen.dart` — กระเป๋าเงิน
8. `notification_screen.dart` — แจ้งเตือน
9. `job_history_screen.dart` — ประวัติการทำงาน
10. `verification_screen.dart` — ยืนยันตัวตน
11. `report_problem_screen.dart` — ร้องเรียน / แจ้งปัญหา
12. `review_screen.dart` — รีวิว
13. `job_map_screen.dart` — แผนที่ + ระยะทางจากผู้ใช้ถึงจุดทำงาน (Google Maps API)
14. `location_picker_screen.dart` — ปักหมุดเลือกตำแหน่งงานตอนโพสต์งาน

## อัปโหลดรูปภาพ (Cloudinary แทน Firebase Storage)
Firebase Storage บังคับแผน Blaze (ต้องผูกบัตร) ตั้งแต่ ก.พ. 2026 —
โปรเจกต์นี้เลยใช้ **Cloudinary** แทน (ฟรี ไม่ต้องผูกบัตร) เก็บแค่ URL
รูปไว้ใน Firestore

**ตั้งค่าก่อนใช้:**
1. สมัครฟรีที่ https://cloudinary.com/users/register/free
2. Dashboard → คัดลอก **Cloud name**
3. Settings → Upload → Upload presets → Add upload preset →
   Signing Mode = **Unsigned** → Save → คัดลอกชื่อ preset
4. แก้ค่าเริ่มต้นใน `lib/services/upload_service.dart`:
   ```dart
   UploadService(
     cloudName: 'ใส่ cloud name ของคุณ',
     uploadPreset: 'ใส่ชื่อ upload preset ของคุณ',
   )
   ```
   (หรือส่งเป็นพารามิเตอร์ตอนสร้าง `UploadService()` ในแต่ละหน้าก็ได้)

**ใช้งานแล้วในหน้า:**
- `verification_screen.dart` — อัปโหลดบัตรนักศึกษา/บัตรประชาชน → บันทึก URL ลง Firestore (`students/{uid}`, field `std_card_url`)
- `post_job_screen.dart` — อัปโหลดรูปประกาศงาน

## ระบบเข้าสู่ระบบ / สมัครสมาชิก / บทบาทผู้ใช้ (Auth + Role)
- `lib/services/auth_service.dart` — สมัคร/เข้าสู่ระบบ/ออกจากระบบด้วย
  Firebase Auth จริง ตอนสมัครจะเขียน `users/{uid}` (u_email, u_role,
  u_created_at) พร้อมสร้างแถวใน `employers/{uid}` หรือ `students/{uid}`
  ตามบทบาทที่เลือก (ตรงกับตารางที่ 3.1–3.3 ในเอกสาร)
- `lib/models/user_role.dart` — ค่าคงที่ `UserRole.employer` /
  `UserRole.student`
- `login_screen.dart` — แท็บ "สมัครสมาชิก" ตอนนี้มีฟอร์มจริง: ชื่อ-นามสกุล,
  ปุ่มเลือกบทบาท (ผู้จ้างงาน / นักศึกษาผู้รับงาน), อีเมล, รหัสผ่าน —
  ไม่ใช่แค่เปลี่ยนสีปุ่มเฉยๆ แล้ว
- `profile_screen.dart` — ปุ่ม "ออกจากระบบ" เรียก `signOut()` จริง
  (มี dialog ยืนยันก่อน) แล้วพากลับไปหน้า Login
- `home_screen.dart` — โหลด role ของผู้ใช้ตอนเปิดหน้า ถ้าเป็น
  **ผู้จ้างงาน** จะเห็นปุ่ม "โพสต์งาน" ถ้าเป็น **นักศึกษา** จะไม่เห็น
  (ตรงกับสโคป 3.1.1 ผู้จ้างงาน vs 3.1.2 นักศึกษาผู้รับงาน)

## ระบบเงิน (Escrow) และตำแหน่ง (LBS)
- `lib/services/wallet_service.dart` — จ่ายเงินเข้า escrow / โอนให้นักศึกษา / คืนเงิน
  ทั้งหมดผ่าน Firestore `runTransaction` กันเงินหาย ดู state machine ที่
  `lib/models/job_model.dart` (`JobStatus`: Open → Process → Done/Cancel)
- `lib/services/location_service.dart` — ขอสิทธิ์ตำแหน่ง, หาตำแหน่งปัจจุบัน,
  คำนวณระยะทาง (กม./ม.) ระหว่างผู้ใช้กับจุดทำงาน
- `PostJobScreen` → แตะช่อง "สถานที่" เปิด `LocationPickerScreen` ให้ปักหมุด
  แล้วได้ `job_lat`/`job_lng` กลับมาเก็บลง Firestore
- `JobDetailScreen` → ปุ่ม "ดูแผนที่ / ระยะทาง" เปิด `JobMapScreen`

### ต้องตั้งค่าเพิ่มก่อนใช้แผนที่ได้จริง
1. สมัคร Google Maps API Key (Maps SDK for Android / iOS) ที่
   https://mapsplatform.google.com
2. Android: ใส่ key ใน `android/app/src/main/AndroidManifest.xml`
   ```xml
   <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY"/>
   ```
   และเพิ่ม permission `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`
3. iOS: ใส่ key ใน `ios/Runner/AppDelegate.swift` และเพิ่ม
   `NSLocationWhenInUseUsageDescription` ใน `Info.plist`
4. รัน `flutter pub get` ใหม่หลังเพิ่ม `google_maps_flutter` / `geolocator`

⚠️ **zip นี้มีเฉพาะโค้ดใน `lib/` เท่านั้น** ไม่มีโฟลเดอร์ `android/` `ios/`
เพราะไม่ได้สร้างด้วย `flutter create` ใหม่ทั้งโปรเจกต์ — ให้คัดลอกไฟล์ใน
`lib/` ไปวางในโปรเจกต์ Flutter เดิมที่มี `android/`, `ios/`, และตั้งค่า
Firebase ไว้แล้ว ถ้ารัน `flutter run` จาก zip นี้ตรง ๆ จะหา platform
target ไม่เจอ

## โครงสร้าง
- `lib/theme/app_theme.dart` — สี, รัศมีขอบ, และ `EmptyState` widget ที่ใช้ซ้ำทุกหน้า
- `lib/widgets/bottom_nav.dart` — แถบเมนูล่าง 5 ปุ่ม
- `lib/screens/` — หน้าจอทั้งหมด
- `lib/main.dart` — เมนูรวมไว้เปิดดูทุกหน้า (ลบออกได้เมื่อจะเอาไปต่อกับ router จริง)

## นำไปใช้กับโปรเจกต์เดิม
คัดลอกโฟลเดอร์ `lib/screens`, `lib/theme`, `lib/widgets` ไปวางในโปรเจกต์ Flutter
ที่มี Firebase อยู่แล้ว แล้วค่อยเชื่อม service (`JobService`, `UserService` ฯลฯ)
เข้ากับแต่ละหน้าแทนที่ empty state
