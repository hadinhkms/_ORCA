import { runProcess } from '@orca/process-host'
import { loadWindowsSecurityAsync } from '../../../../shared/secure-storage/windows-security-addon'
import { secretServiceProcessEnvironment } from '../../../linux-secret-service/session-bus-environment'
import { readKeychainPassword } from '../../../macos-keychain/generic-password'
import type { GeminiCredentials } from './gemini-oauth-sources'

const GEMINI_KEYCHAIN_SERVICE = 'gemini-cli-oauth'
const GEMINI_KEYCHAIN_ACCOUNT = 'main-account'
const WINDOWS_CREDENTIAL_TARGET = `${GEMINI_KEYCHAIN_SERVICE}/${GEMINI_KEYCHAIN_ACCOUNT}`
const LINUX_KEYRING_TIMEOUT_MS = 3_000

export function parseGeminiKeychainCredentials(raw: string): GeminiCredentials | null {
  try {
    const parsed = JSON.parse(raw) as unknown
    if (!parsed || typeof parsed !== 'object' || !('token' in parsed)) {
      return null
    }
    const token = (parsed as { token?: unknown }).token
    if (!token || typeof token !== 'object') {
      return null
    }
    const { accessToken, refreshToken, expiresAt } = token as {
      accessToken?: unknown
      refreshToken?: unknown
      expiresAt?: unknown
    }
    if (typeof accessToken !== 'string' || accessToken.length === 0) {
      return null
    }
    return {
      access_token: accessToken,
      refresh_token: typeof refreshToken === 'string' ? refreshToken : '',
      expiry_date: typeof expiresAt === 'number' && Number.isFinite(expiresAt) ? expiresAt : 0,
      source: 'keychain'
    }
  } catch {
    return null
  }
}

async function readWindowsKeychainRaw(): Promise<string | null> {
  const loaded = await loadWindowsSecurityAsync()
  if ('error' in loaded) {
    return null
  }
  try {
    const bytes = loaded.addon.readGenericCredential(WINDOWS_CREDENTIAL_TARGET)
    if (bytes === null) {
      return null
    }
    return new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes)
  } catch {
    return null
  }
}

async function readLinuxKeychainRaw(): Promise<string | null> {
  try {
    const result = await runProcess({
      program: 'secret-tool',
      args: ['lookup', 'service', GEMINI_KEYCHAIN_SERVICE, 'account', GEMINI_KEYCHAIN_ACCOUNT],
      env: await secretServiceProcessEnvironment(),
      timeoutMs: LINUX_KEYRING_TIMEOUT_MS,
      maxOutputBytes: 64 * 1024
    })
    if (result.code !== 0 || result.timedOut || result.outputTruncated) {
      return null
    }
    const trimmed = result.stdout.trim()
    return trimmed.length > 0 ? trimmed : null
  } catch {
    return null
  }
}

async function readKeychainRaw(): Promise<string | null> {
  if (process.platform === 'win32') {
    return readWindowsKeychainRaw()
  }
  if (process.platform === 'darwin') {
    try {
      return await readKeychainPassword(GEMINI_KEYCHAIN_SERVICE, GEMINI_KEYCHAIN_ACCOUNT)
    } catch {
      return null
    }
  }
  if (process.platform === 'linux') {
    return readLinuxKeychainRaw()
  }
  return null
}

// Gemini CLI >=0.38 migrates ~/.gemini/oauth_creds.json into the OS keychain via @github/keytar.
export async function readGeminiKeychainCredentials(): Promise<GeminiCredentials | null> {
  const raw = await readKeychainRaw()
  if (!raw) {
    return null
  }
  return parseGeminiKeychainCredentials(raw)
}
