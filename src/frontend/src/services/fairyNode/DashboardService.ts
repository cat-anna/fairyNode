import { RestServiceBase } from './RestServiceBase'

export interface DeviceEntry {
  name: string
  device_id: string
  hardware_id: string
}

export interface SummaryDeviceEntry extends DeviceEntry {
  status: string
  errors: number
  uptime: number
}

export interface DeviceNodeProperty {
  name: string
  id: string
  global_id: string
  property_id: string
  datatype: string
  value: string
  unit: string
  retained: boolean
  settable: boolean
  timestamp: number
}

export interface DeviceNode {
  name: string
  id: string
  global_id: string
  properties: DeviceNodeProperty[]
}

export declare type PropertyTypes = boolean | number | string

export interface ChartSeriesSourceInfo {
  global_id: string
  device: string
}
export interface ChartSeriesInfo {
  name: string
  unit: string
  values: ChartSeriesSourceInfo[]
}

export class DashboardService extends RestServiceBase {
  constructor() {
    super('dashboard')
  }

  summary(): Promise<SummaryDeviceEntry[]> {
    return this.get_json('/summary')
  }

  getStatusColor(status: string): string {
    if (status === 'ready') {
      return 'success'
    }
    if (status === 'init') {
      return 'warning'
    }
    return 'danger'
  }
}

export default new DashboardService()
