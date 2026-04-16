import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'DonorSignUp_Page.dart';
import 'welcome_page.dart';
import 'main_navigation.dart';
import 'Hospital_navigation_page.dart';
import 'blood_bank_navigation.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  Future<void> _login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("أدخل البريد وكلمة المرور")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = credential.user!;
      final uid = user.uid;

      // ── المستشفى ──
      final hospSnap =
          await FirebaseDatabase.instance.ref("Hospitals/$uid").get();

      if (hospSnap.exists) {
        if (mounted) {
          setState(() => isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HospitalNavigation()),
          );
        }
        return;
      }

      // ── المتبرع ──
      final donorSnap =
          await FirebaseDatabase.instance.ref("Donors/$uid").get();

      if (donorSnap.exists) {
        if (!user.emailVerified) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() => isLoading = false);
            _showResendDialog(email, password);
          }
          return;
        }

        if (mounted) {
          setState(() => isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
        return;
      }

      // ── موظف بنك الدم ──
      final bankSnap =
          await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();

      if (bankSnap.exists && bankSnap.value is Map) {
        final bankData = Map<String, dynamic>.from(bankSnap.value as Map);
        final hospitalId = bankData['hospitalId']?.toString() ?? "";

        if (mounted) {
          setState(() => isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BloodBankNavigation(hospitalId: hospitalId),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("الحساب غير موجود في النظام"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);

        String msg;
        if (e.code == 'user-not-found')
          msg = "الحساب غير موجود";
        else if (e.code == 'wrong-password')
          msg = "كلمة المرور غير صحيحة";
        else if (e.code == 'invalid-email')
          msg = "البريد غير صحيح";
        else if (e.code == 'invalid-credential')
          msg = "بيانات الدخول غير صحيحة";
        else
          msg = "خطأ غير متوقع";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.black87),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e")),
        );
      }
    }
  }

  Future<bool> _isDonorEmail(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
    if (donorsSnap.exists && donorsSnap.value is Map) {
      final map = Map<String, dynamic>.from(donorsSnap.value as Map);
      for (final entry in map.values) {
        final d = Map<String, dynamic>.from(entry as Map);
        if ((d['email']?.toString().toLowerCase().trim()) == normalizedEmail) {
          return true;
        }
      }
    }
    return false;
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "نسيت كلمة المرور؟",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة تعيين كلمة المرور.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailResetController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "أدخل البريد الإلكتروني";
                  if (!v.contains('@')) return "بريد غير صالح";
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "البريد الإلكتروني",
                  prefixIcon:
                      const Icon(Icons.email_outlined, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _sendPasswordReset(emailResetController.text.trim());
            },
            child: const Text(
              "إرسال الرابط",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset(String email) async {
    final isDonor = await _isDonorEmail(email);
    if (!isDonor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("لا يوجد حساب متبرع مسجّل بهذا البريد الإلكتروني"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم إرسال رابط إعادة التعيين، تحقق من بريدك"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.code == 'user-not-found'
                ? "لا يوجد حساب بهذا البريد"
                : "حدث خطأ، حاول مرة أخرى"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResendDialog(String email, String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "البريد غير مفعّل",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "لم يتم تفعيل بريدك الإلكتروني بعد.\n"
          "يرجى فتح رسالة التفعيل المرسلة إلى بريدك.\n\n"
          "هل تريد إعادة إرسال رابط التفعيل؟",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("لاحقاً", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _resendVerificationEmail(email, password);
            },
            child: const Text(
              "إعادة الإرسال",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await credential.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم إرسال رابط التفعيل، تحقق من بريدك"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الإرسال: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WelcomePage()),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Image.asset("assets/welcomepage.png", height: 180),
                    const SizedBox(height: 10),
                    Text(
                      "VivaLink",
                      style: GoogleFonts.atma(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "البريد الإلكتروني",
                        prefixIcon:
                            const Icon(Icons.email_outlined, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: "كلمة المرور",
                        prefixIcon:
                            const Icon(Icons.lock_outline, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          "نسيت كلمة المرور؟",
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isLoading ? null : _login,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                "تسجيل الدخول",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "ليس لديك حساب؟ ",
                          style: TextStyle(fontSize: 18),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DonorSignUpPage(),
                            ),
                          ),
                          child: const Text(
                            "إنشاء حساب",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── overlay شفاف أثناء التحميل يمنع الضغط ──
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}