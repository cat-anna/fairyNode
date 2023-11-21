import { RestServiceBase } from './RestServiceBase'

// export declare type PropertyTypes = boolean | number | string;

export interface ChartSeriesListEntry {
  display_name: string
  global_id: string
}

export interface ChartSeries {
  unit?: string
  name?: string
  id: string
  series: ChartSeriesListEntry[]
}

export interface ChartSeriesValueEntry {
  timestamp: number
  value: number
}

export interface ChartSeriesData {
  from: number
  to: number
  list: ChartSeriesValueEntry[]
}

export interface ChartSeriesInfo {
  groups?: ChartSeries[]
  units?: ChartSeries[]
  device?: ChartSeries[]
}

export class PropertyService extends RestServiceBase {
  constructor() {
    super('property')
  }

  chartSeries(): Promise<ChartSeriesInfo> {
    return this.get_json('/chart/series')
  }

  valueHistory(value_id: string, from: number | null = null, to: number | null = null): Promise<ChartSeriesData> {
    const args: string[] = []
    if (from != null) args.push('from=' + from.toString())
    if (to != null) args.push('to=' + to.toString())
    return this.get_json('/value/' + value_id + '/history?' + args.join('&'))
  }
  valueHistoryLast(value_id: string, last: number): Promise<ChartSeriesData> {
    return this.get_json('/value/' + value_id + '/history?last=' + last.toString())
  }
}

export default new PropertyService()
