/// Base URL of the deployed sync/notifications/challenges backend.
const String syncApiBaseUrl = 'https://breath.lysyweb.pl';

/// Applied to every request — without it, a hung connection (the backend
/// unreachable, a dead proxy) would leave "SYNCING..."/a login attempt
/// spinning forever instead of failing visibly.
const Duration syncRequestTimeout = Duration(seconds: 20);
