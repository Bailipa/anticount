/// 环境变量配置
///
/// 通过 [AppEnvironment] 控制应用运行环境（dev / staging / prod）。
/// 不同环境可对应不同的数据库文件名、API 地址等配置。
///
/// 也可通过 --dart-define=ENV=prod 编译期注入环境。
class EnvConfig {
  const EnvConfig({
    required this.appName,
    required this.dbName,
  });

  final String appName;
  final String dbName;
}

enum AppEnvironment { dev, staging, prod }

/// 通过编译期 dart-define 注入环境，默认 dev
const AppEnvironment _kEnv = String.fromEnvironment(
  'ENV',
  defaultValue: 'dev',
) == 'prod'
    ? AppEnvironment.prod
    : String.fromEnvironment('ENV', defaultValue: 'dev') == 'staging'
        ? AppEnvironment.staging
        : AppEnvironment.dev;

/// 当前环境配置
final EnvConfig currentEnv = _resolveEnv(_kEnv);

EnvConfig _resolveEnv(AppEnvironment env) {
  switch (env) {
    case AppEnvironment.prod:
      return const EnvConfig(
        appName: 'Anticount',
        dbName: 'anticount.db',
      );
    case AppEnvironment.staging:
      return const EnvConfig(
        appName: 'Anticount (Staging)',
        dbName: 'anticount_staging.db',
      );
    case AppEnvironment.dev:
      return const EnvConfig(
        appName: 'Anticount (Dev)',
        dbName: 'anticount_dev.db',
      );
  }
}
