import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "سياسة الخصوصية والاستخدام",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── بطاقة الترحيب ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "سياسة الخصوصية والاستخدام",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "تطبيق VivaLink — آخر تحديث: 2025",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 10),
                Text(
                  "نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. "
                  "يرجى قراءة هذه السياسة بعناية قبل استخدام التطبيق.",
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ════════════════════════════════
          // شروط الاستخدام
          // ════════════════════════════════
          _buildSectionHeader("📋 أولاً: شروط الاستخدام"),
          const SizedBox(height: 12),

          _buildSection(
            icon: Icons.person_outline,
            title: "١. أهلية الاستخدام",
            color: Colors.blue,
            bullets: [
              "يجب أن يكون عمر المستخدم ١٨ عاماً أو أكثر",
              "يجب تقديم معلومات صحيحة ودقيقة عند التسجيل",
              "يُحظر إنشاء أكثر من حساب واحد لنفس الشخص",
              "يُحظر استخدام التطبيق لأغراض غير مشروعة أو ضارة",
            ],
          ),

          _buildSection(
            icon: Icons.bloodtype_outlined,
            title: "٢. قواعد التبرع",
            color: Colors.red,
            bullets: [
              "التبرع بالدم يجب أن يكون طوعياً وبإرادة المتبرع الكاملة",
              "يلتزم المتبرع بانتظار ٤ أشهر (١٢٠ يوماً) بين كل تبرع وآخر",
              "يجب الالتزام بالحضور بعد تأكيد التبرع",
              "إذا تعذّر الحضور، يرجى إلغاء الالتزام في أقرب وقت",
            ],
          ),

          _buildSection(
            icon: Icons.local_hospital_outlined,
            title: "٣. العلاقة مع المستشفيات",
            color: Colors.orange,
            bullets: [
              "التطبيق وسيط فقط بين المتبرع والمستشفى",
              "المستشفيات هي المسؤولة عن إجراءات التبرع الطبية",
              "التطبيق غير مسؤول عن أي قرار طبي يتخذه الطاقم الصحي",
              "المعلومات الطبية في التطبيق إرشادية وليست بديلاً عن الاستشارة الطبية",
            ],
          ),

          _buildSection(
            icon: Icons.block_outlined,
            title: "٤. السلوك المحظور",
            color: Colors.deepOrange,
            bullets: [
              "تقديم معلومات صحية كاذبة أو مضللة",
              "محاولة الوصول لبيانات مستخدمين آخرين",
              "استخدام التطبيق بأي طريقة تضر بالمستخدمين الآخرين",
              "نشر أي محتوى مسيء أو غير لائق",
            ],
          ),

          _buildSection(
            icon: Icons.gavel_outlined,
            title: "٥. إخلاء المسؤولية",
            color: Colors.brown,
            content:
                "التطبيق يُقدَّم \"كما هو\" دون أي ضمانات. لا يتحمل فريق VivaLink "
                "المسؤولية عن أي أضرار مباشرة أو غير مباشرة ناتجة عن استخدام التطبيق. "
                "التطبيق ليس خدمة طوارئ طبية — في حالات الطوارئ اتصل بالإسعاف فوراً.",
          ),

          _buildSection(
            icon: Icons.update_outlined,
            title: "٦. تعديل الشروط",
            color: Colors.indigo,
            content:
                "نحتفظ بحق تعديل هذه الشروط في أي وقت. سيتم إشعارك بالتغييرات "
                "الجوهرية عبر التطبيق. استمرارك في الاستخدام يعني موافقتك على الشروط المحدّثة.",
          ),

          const SizedBox(height: 24),

          // ════════════════════════════════
          // سياسة الخصوصية
          // ════════════════════════════════
          _buildSectionHeader("🔒 ثانياً: سياسة الخصوصية"),
          const SizedBox(height: 12),

          _buildSection(
            icon: Icons.storage_outlined,
            title: "٧. البيانات التي نجمعها",
            color: Colors.purple,
            bullets: [
              "الاسم الكامل ورقم الهاتف والبريد الإلكتروني",
              "فصيلة الدم والمدينة",
              "تاريخ التبرعات السابقة وعددها",
              "نسبة الهيموغلوبين وتاريخ آخر فحص دم",
              "الأمراض المزمنة (إن وُجدت) لتحديد الأهلية فقط",
              "صور فحوصات الدم الدورية",
            ],
            warningText:
                "جميع البيانات الصحية تُعامَل باعتبارها بيانات حساسة وتخضع لحماية مشددة.",
          ),

          _buildSection(
            icon: Icons.security_outlined,
            title: "٨. كيف نحمي بياناتك",
            color: Colors.green,
            bullets: [
              "تخزين البيانات على Firebase بتشفير SSL/TLS",
              "صور الفحوصات محفوظة على Supabase Storage بصلاحيات محدودة",
              "كلمات المرور مشفرة ولا يمكن الاطلاع عليها من أي جهة",
              "التحقق من البريد الإلكتروني إلزامي عند التسجيل",
            ],
          ),

          _buildSection(
            icon: Icons.share_outlined,
            title: "٩. مشاركة البيانات",
            color: Colors.teal,
            content:
                "تُشارَك بياناتك فقط مع المستشفيات وبنوك الدم المسجلة في التطبيق "
                "وذلك لتيسير عملية التبرع. لا نبيع بياناتك ولا نشاركها مع أي جهة "
                "تجارية أو إعلانية أو طرف ثالث خارج نطاق التطبيق.",
          ),

          _buildSection(
            icon: Icons.manage_accounts_outlined,
            title: "١٠. حقوقك",
            color: Colors.cyan,
            bullets: [
              "حق الاطلاع على بياناتك الشخصية في أي وقت",
              "حق تعديل أو تحديث بياناتك من صفحة تعديل الحساب",
              "حق حذف حسابك ومعه جميع بياناتك بالكامل",
              "حق الاعتراض على أي معالجة لبياناتك",
            ],
          ),

          _buildSection(
            icon: Icons.notifications_outlined,
            title: "١١. الإشعارات",
            color: Colors.amber,
            content:
                "نرسل لك إشعارات تتعلق بطلبات الدم العاجلة في مدينتك فقط. "
                "يمكنك إيقاف الإشعارات في أي وقت من إعدادات جهازك. "
                "لن نرسل لك أي إشعارات دعائية أو تسويقية.",
          ),

          _buildSection(
            icon: Icons.contact_support_outlined,
            title: "١٢. التواصل معنا",
            color: Colors.blueGrey,
            content:
                "إذا كان لديك أي استفسار حول هذه السياسة أو بياناتك، "
                "يمكنك التواصل معنا عبر:\n📧 support@vivalink.app",
          ),

          const SizedBox(height: 20),

          // ── footer ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 28),
                SizedBox(height: 8),
                Text(
                  "شكراً لثقتك بـ VivaLink",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  "تبرعاتك تُنقذ أرواحاً 🩸",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    String content = "",
    List<String> bullets = const [],
    String? warningText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border:
                  Border(bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // المحتوى
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bullets.isNotEmpty)
                  ...bullets.map((b) => _bulletPoint(b)),
                if (content.isNotEmpty)
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.right,
                  ),
                if (warningText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warningText,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 7, color: Colors.red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}