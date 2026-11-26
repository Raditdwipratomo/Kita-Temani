import 'package:flutter/material.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/features/articles/domain/entities/article.dart';
import 'package:kitatemani/features/articles/presentation/screens/article_composer_screen.dart';
import 'package:kitatemani/features/articles/presentation/screens/article_detail_screen.dart';
import 'package:kitatemani/features/articles/presentation/screens/articles_feed_screen.dart';
import 'package:kitatemani/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:kitatemani/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:kitatemani/features/auth/presentation/screens/school_login_screen.dart';
import 'package:kitatemani/features/auth/presentation/screens/splash_screen.dart';
import 'package:kitatemani/features/camera/presentation/screens/camera_screen.dart';
import 'package:kitatemani/features/curhai/presentation/screens/curhai_screen.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/screens/add_contact_screen.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/screens/emergency_contacts_screen.dart';
import 'package:kitatemani/features/home/presentation/screens/home_screen.dart';
import 'package:kitatemani/features/panic/presentation/screens/panic_button_screen.dart';
import 'package:kitatemani/features/panic/presentation/screens/panic_status_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/app_permissions_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/profile_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_review_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_sent_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_story_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_type_screen.dart';
import 'package:kitatemani/features/school_summary/presentation/screens/school_summary_screen.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
      case AppRoutes.onboarding:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OnboardingScreen(),
        );
      case AppRoutes.schoolLogin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SchoolLoginScreen(),
        );
      case AppRoutes.completeProfile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CompleteProfileScreen(),
        );
      case AppRoutes.home:
        final tabIndex =
            settings.arguments is int ? settings.arguments! as int : 0;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => HomeScreen(initialTabIndex: tabIndex),
        );
      case AppRoutes.myReports:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(initialTabIndex: 2),
        );
      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfileScreen(isTabView: false),
        );
      case AppRoutes.editProfile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const EditProfileScreen(),
        );
      case AppRoutes.appPermissions:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppPermissionsScreen(),
        );
      case AppRoutes.reportType:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReportTypeScreen(),
        );
      case AppRoutes.reportStory:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReportStoryScreen(),
        );
      case AppRoutes.reportReview:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReportReviewScreen(),
        );
      case AppRoutes.reportSent:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReportSentScreen(),
        );
      case AppRoutes.reportDetail:
        final code =
            settings.arguments is String ? settings.arguments! as String : '';
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ReportDetailScreen(reportCode: code),
        );
      case AppRoutes.panic:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PanicButtonScreen(),
        );
      case AppRoutes.panicActive:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PanicStatusScreen(),
        );
      case AppRoutes.camera:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CameraScreen(),
        );
      case AppRoutes.emergencyContacts:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const EmergencyContactsScreen(),
        );
      case AppRoutes.addContact:
        final existing = settings.arguments is EmergencyContact
            ? settings.arguments! as EmergencyContact
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AddContactScreen(existingContact: existing),
        );
      case AppRoutes.curhai:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CurhaiScreen(),
        );
      case AppRoutes.schoolSummary:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SchoolSummaryScreen(),
        );
      case AppRoutes.articles:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ArticlesFeedScreen(),
        );
      case AppRoutes.articleDetail:
        var articleId = '';
        var scrollToComments = false;
        if (settings.arguments is String) {
          articleId = settings.arguments! as String;
        } else if (settings.arguments is Map) {
          final args = Map<String, dynamic>.from(settings.arguments! as Map);
          articleId = (args['articleId'] ?? '').toString();
          scrollToComments = args['scrollToComments'] == true;
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ArticleDetailScreen(
            articleId: articleId,
            scrollToComments: scrollToComments,
          ),
        );
      case AppRoutes.articleCompose:
        final editing = settings.arguments is ArticleItem
            ? settings.arguments! as ArticleItem
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ArticleComposerScreen(editingArticle: editing),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
    }
  }
}
