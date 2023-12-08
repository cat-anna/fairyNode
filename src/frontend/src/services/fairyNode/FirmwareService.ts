import { RestServiceBase, GenericResult } from './RestServiceBase'

export interface DeviceCommit {
  timestamp: number
  boot_successful: boolean
  components: Map<string, string>
  key: string
}

export interface DeviceCommitStatus {
  current: string
  active: string
  commits: DeviceCommit[]
}

export class FirmwareService extends RestServiceBase {
  constructor() {
    super('firmware')
  }

  listCommitsForDevice(device_id: string): Promise<DeviceCommitStatus> {
    return this.get_json('/device/' + device_id + '/commit')
  }
  activateCommitForDevice(device_id: string, commit: string): Promise<GenericResult> {
    return this.post_json('/device/' + device_id + '/commit/' + commit + '/activate', {})
  }
}

export default new FirmwareService()
