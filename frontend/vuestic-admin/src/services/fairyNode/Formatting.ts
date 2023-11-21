import { ChartSeriesValueEntry } from './PropertyService'

export interface ChartPoint {
  x: any
  y: any
}

class Formatting {
  public formatSeconds(duration: number): string {
    if (duration == null) {
      return '&lt;?&gt;'
    }

    let hours = Math.floor(duration / 3600)
    const minutes = Math.floor((duration - hours * 3600) / 60)
    const seconds = duration - hours * 3600 - minutes * 60
    const days = Math.floor(hours / 24)
    hours = hours - days * 24

    const str_days = this.pad(Math.round(days).toString(), 3)
    const str_hours = this.pad(Math.round(hours).toString(), 2)
    const str_minutes = this.pad(Math.round(minutes).toString(), 2)
    const str_seconds = this.pad(Math.round(seconds).toString(), 2)

    return str_days + 'd ' + str_hours + ':' + str_minutes + ':' + str_seconds
  }

  public formatTimestamp(timestamp: number): string {
    if (!timestamp) {
      return ''
    }
    return new Date(timestamp * 1000).toLocaleString()
  }

  public pad(num: string, size: number): string {
    while (num.length < size) num = '0' + num
    return num
  }

  public TimestampToMilliseconds(v: number): number {
    return v * 1000
  }

  public transformChartSeries(list: ChartSeriesValueEntry[]): ChartPoint[] {
    const r = new Array<ChartPoint>()
    for (const key in list) {
      const item = list[key]
      r.push({
        x: this.TimestampToMilliseconds(item.timestamp),
        y: item.value,
      })
    }
    return r
  }
}

export default new Formatting()
