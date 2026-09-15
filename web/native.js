// Capacitor supplies native plugins through its bridge; browsers use an explicit fallback.
export const native = () => !!window.Capacitor?.isNativePlatform?.();
export async function reminders(settings) {
  const plugin = window.Capacitor?.Plugins?.LocalNotifications;
  if (!plugin)
    return {
      native: false,
      message:
        "Scheduled reminders work in the Android build. This browser shows reminders while Study Arena is open.",
    };
  const pending = await plugin.getPending();
  if (pending.notifications.length)
    await plugin.cancel({ notifications: pending.notifications });
  if (!settings.reminders || settings.daily_cap === 0) return { native: true };
  const permission = await plugin.requestPermissions();
  if (permission.display !== "granted") return { native: true, denied: true };
  const [hour, minute] = settings.reminder_time.split(":").map(Number);
  const quiet =
    settings.quiet_start < settings.quiet_end
      ? hour >= settings.quiet_start && hour < settings.quiet_end
      : settings.quiet_start > settings.quiet_end &&
        (hour >= settings.quiet_start || hour < settings.quiet_end);
  if (quiet)
    return {
      native: true,
      message: "Reminder falls within quiet hours and will be skipped.",
    };
  const notifications = [];
  // Schedule a bounded rolling week, one local reminder/day. Remote notifications share the remaining cap.
  for (let day = 0; day < 7; day++) {
    const at = new Date();
    at.setDate(at.getDate() + day);
    at.setHours(hour, minute, 0, 0);
    if (at > new Date())
      notifications.push({
        id: 1000 + day,
        title: "Your quiet study moment",
        body: "A few minutes with one topic is a good start.",
        schedule: { at },
        smallIcon: "ic_stat_icon",
      });
  }
  await plugin.schedule({ notifications });
  return { native: true };
}
export async function pushRegistration(client) {
  const push = window.Capacitor?.Plugins?.PushNotifications;
  if (!push) return false;
  const result = await push.requestPermissions();
  if (result.receive !== "granted") return false;
  await push.addListener("registration", (token) =>
    client
      .mutate("/api/push/register", { token: token.value, platform: "android" })
      .catch(() => {}),
  );
  await push.register();
  return true;
}
