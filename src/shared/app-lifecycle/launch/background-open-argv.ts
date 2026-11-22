/** `orca open` launches carry this so Orca shows its window without taking the foreground. */
export const BACKGROUND_OPEN_ARG = '--orca-background-open'

/** Login-item launches carry this so Orca starts its server in the tray without showing a window. */
export const START_IN_TRAY_ARG = '--orca-start-in-tray'

export function argvRequestsBackgroundOpen(argv: readonly string[]): boolean {
  return argv.includes(BACKGROUND_OPEN_ARG)
}

export function argvRequestsStartInTray(argv: readonly string[]): boolean {
  return argv.includes(START_IN_TRAY_ARG)
}
