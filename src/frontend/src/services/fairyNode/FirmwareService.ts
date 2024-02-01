import { RestServiceBase, GenericResult } from './RestServiceBase'

export interface DeviceCommit {
  timestamp: number
  boot_successful: boolean
  components: Map<string, string>
  key: string
}

export interface DeviceCommitResponse {
  current: string
  active: string
  commits: DeviceCommit[]
}

export interface DeviceNodeMcuInfo {
  lfs_size: number
  git_commit_id: string
}

export interface DeviceFirmwareStatus {
  current?: DeviceCommit
  active?: DeviceCommit
}

export interface DeviceFirmwareStatusResponse {
  nodeMcu: DeviceNodeMcuInfo
  firmware: DeviceFirmwareStatus
}

export class FirmwareService extends RestServiceBase {
  constructor() {
    super('firmware')
  }

  triggerOta(device_id: string): Promise<GenericResult> {
    return this.post_json('/device/' + device_id + '/update', {})
  }

  deviceStatus(device_id: string): Promise<DeviceFirmwareStatusResponse> {
    return this.get_json('/device/' + device_id + '/status')
  }

  listCommitsForDevice(device_id: string): Promise<DeviceCommitResponse> {
    return this.get_json('/device/' + device_id + '/commit')
  }
  activateCommitForDevice(device_id: string, commit: string): Promise<GenericResult> {
    return this.post_json('/device/' + device_id + '/commit/' + commit + '/activate', {})
  }
  deleteDeviceCommit(device_id: string, commit: string): Promise<GenericResult> {
    return this.post_json('/device/' + device_id + '/commit/' + commit + '/delete', {})
  }
}

export default new FirmwareService()
