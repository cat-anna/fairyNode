
import http from "./http-common";
import {GenericResult} from "./http-common";

export interface DeviceCommit {
    timestamp: number
    boot_successful: boolean
    components: Map<string,string>
    key: string
}

export interface DeviceCommitStatus {
    current: string
    active: string
    commits: DeviceCommit[]
}

export class FirmwareService {
    get_json(url: string) { return http.get_json("/firmware" + url); }
    post_json(url: string, data: object) { return http.post_json("/firmware" + url, data); }

    listCommitsForDevice(device_id: string) : Promise<DeviceCommitStatus> {
        return this.get_json("/device/" + device_id + "/commit")
    }
    activateCommitForDevice(device_id: string, commit: string) : Promise<GenericResult> {
        return this.post_json("/device/" + device_id + "/commit/" + commit + "/activate", { })
    }
}

export default new FirmwareService();
