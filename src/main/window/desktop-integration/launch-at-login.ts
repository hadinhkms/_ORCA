import { mkdirSync, unlinkSync, writeFileSync } from 'node:fs'
import os from 'node:os'
import { join } from 'node:path'
import { app } from 'electron'
import { START_IN_TRAY_ARG } from '../../../shared/app-lifecycle/launch/background-open-argv'
import { mainProcessState as state } from '../../startup/main-process-state'
import {
  isBackgroundLaunch,
  isOrcadSidecarLaunch
} from '../activation/foreground-activation-policy'

function escapeDesktopExecArg(value: string): string {
  return `"${value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
}

function resolveLinuxAutostartPath(env: NodeJS.ProcessEnv = process.env): string {
  const configRoot = env.XDG_CONFIG_HOME?.trim() || join(os.homedir(), '.config')
  return join(configRoot, 'autostart', 'orca.desktop')
}

function syncLinuxAutostart(enabled: boolean, execPath: string, env: NodeJS.ProcessEnv): void {
  const desktopFilePath = resolveLinuxAutostartPath(env)
  if (!enabled) {
    try {
      unlinkSync(desktopFilePath)
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
        throw error
      }
    }
    return
  }
  const targetExecutable = env.APPIMAGE?.trim() || execPath
  mkdirSync(join(desktopFilePath, '..'), { recursive: true })
  const contents = [
    '[Desktop Entry]',
    'Type=Application',
    'Name=Orca',
    `Exec=${escapeDesktopExecArg(targetExecutable)} ${START_IN_TRAY_ARG}`,
    'Terminal=false',
    'X-GNOME-Autostart-enabled=true',
    ''
  ].join('\n')
  writeFileSync(desktopFilePath, contents, 'utf8')
}

/**
 * Registers or removes Orca as an OS login item so the desktop server starts in the tray on boot.
 * Only packaged desktop launches touch OS startup entries; dev, E2E, serve, and sidecar runs skip.
 */
export function syncLaunchAtLoginSetting(enabled: boolean): void {
  if (
    !app.isPackaged ||
    state.isServeMode ||
    isBackgroundLaunch() ||
    isOrcadSidecarLaunch() ||
    Boolean(process.env.ORCA_E2E_USER_DATA_DIR)
  ) {
    return
  }
  try {
    if (process.platform === 'linux') {
      syncLinuxAutostart(enabled, process.execPath, process.env)
      return
    }
    if (process.platform === 'win32' || process.platform === 'darwin') {
      app.setLoginItemSettings({
        openAtLogin: enabled,
        ...(process.platform === 'win32' ? { path: process.execPath } : { openAsHidden: enabled }),
        args: enabled ? [START_IN_TRAY_ARG] : []
      })
    }
  } catch (error) {
    console.warn('[startup] Failed to update launch-at-login setting:', error)
  }
}
