abstract class AppStates {}

class AppInitialState extends AppStates {}

class AppChangeBottomNavState extends AppStates {}

// حالات الـ الأشواط
class AppRoundIncrementState extends AppStates {}

class AppRoundResetState extends AppStates {}

// حالات أشواط السعي (الصفا ↔ المروة)
class AppSaiIncrementState extends AppStates {}

class AppSaiResetState extends AppStates {}

// الحالات الجديدة للبوصلة والازدحام الجغرافي
class AppQiblaDirectionUpdateState extends AppStates {}

class AppMapCrowdDensityUpdateState extends AppStates {}

// حالات الـ SOS
class AppSOSSuccessState extends AppStates {}

class AppSOSErrorState extends AppStates {}

// حالات لوحة الأدمن والإحصائيات
class AppAdminLoadingStatsState extends AppStates {}

class AppAdminGetStatsSuccessState extends AppStates {}

class AppAdminGetStatsErrorState extends AppStates {
  final String error;
  AppAdminGetStatsErrorState(this.error);
}

class AppAdminGetSOSRequestsSuccessState extends AppStates {}

class AppAdminGetSOSRequestsErrorState extends AppStates {
  final String error;
  AppAdminGetSOSRequestsErrorState(this.error);
}