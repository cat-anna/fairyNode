
import http from "./http-common";

export interface DeviceEntry {
  name: string;
  id: string;
}

export interface SummaryDeviceEntry extends DeviceEntry {
  status: string;
  errors: number;
  uptime: number;
}

export class DeviceService {
  summary() : Promise<SummaryDeviceEntry[]> {
    return http.get_json("/device/summary");
  }
  list() : Promise<DeviceEntry[]> {
    return http.get_json("/device/list");
  }

  getStatusColor(status: string){
    if (status === 'ready') {
      return 'success'
    }

    if (status === 'init') {
      return 'warning'
    }

    return 'danger'
  }
}

export default new DeviceService();
