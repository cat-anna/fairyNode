import formatting from '../../../services/fairyNode/Formatting'
import propertyService from '../../../services/fairyNode/PropertyService'
import { TLineChartData } from '../../../data/types'
class DatasetState {
  seriesId: string
  dataset: any
  owner: any
  lastTimestamp = 0
  ready = false
  dataDuration: number

  constructor(owner: any, seriesId: string, datasets: Array<any>, dataDuration: number) {
    this.seriesId = seriesId
    this.owner = owner
    this.dataDuration = dataDuration

    this.dataset = {
      label: '',
      data: [],
    }
    datasets.push(this.dataset)

    this.reload()
  }

  reload() {
    this.ready = false
    this.owner.datasetChanged()

    propertyService
      .valueHistoryLast(this.seriesId, this.dataDuration)
      .then((history) => {
        this.dataset.data = formatting.transformChartSeries(history.list)
        if (history.device) {
          this.dataset.label = history.device + ' ' + history.name
        } else {
          this.dataset.label = history.name
        }

        const last = history.list.at(-1)
        if (last) {
          this.lastTimestamp = last.timestamp
        } else {
          this.lastTimestamp = history.from
        }

        this.ready = true
        this.owner.datasetChanged()
      })
      .catch(() => {
        this.dataset.label = 'Failed to load'
        this.ready = true
        this.owner.datasetChanged()
      })
  }

  setDuration(number: number) {
    this.dataDuration = number
    this.reload()
  }

  update() {
    propertyService.valueHistory(this.seriesId, this.lastTimestamp).then((update) => {
      const filtered = update.list.filter((e) => this.lastTimestamp < e.timestamp)
      if (filtered.length == 0) {
        return
      }

      const data = formatting.transformChartSeries(filtered)
      this.dataset.data.push(...data)

      const now = Date.now()
      const millis = formatting.TimestampToMilliseconds(this.dataDuration)

      while (this.dataset.data.length > 0 && now - this.dataset.data[0].x > millis) {
        this.dataset.data.shift()
      }

      const last = update.list.at(-1)
      if (last) {
        this.lastTimestamp = last.timestamp
      }

      this.owner.datasetChanged()
    })
  }
}

export class ChartState {
  name: string
  chartData: TLineChartData
  ready: boolean
  updateFunc?: (b: boolean) => void
  datasets: Array<DatasetState>
  dataDuration: number
  id: number

  constructor(seriesId: string[], name: string, dataDuration: number, id: number) {
    this.name = name
    this.chartData = <TLineChartData>{}
    this.ready = false
    this.datasets = new Array<DatasetState>()
    this.dataDuration = dataDuration
    this.id = id

    this.reset(seriesId, name)
  }

  async update() {
    this.datasets.forEach((e) => e.update())
  }

  getSeriesIdList(): string[] {
    const ret: string[] = []
    this.datasets.forEach((set) => ret.push(set.seriesId))
    return ret
  }

  reset(seriesId: string[], name: string) {
    this.name = name
    this.chartData.labels = []
    this.chartData.datasets = []
    this.datasets = new Array<DatasetState>()

    seriesId.sort((a, b) => {
      return a.localeCompare(b)
    })

    seriesId.forEach((entry) => {
      this.datasets.push(new DatasetState(this, entry, this.chartData.datasets, this.dataDuration))
    })
  }

  setDuration(number: number) {
    this.datasets.forEach((e) => {
      e.setDuration(number)
    })
  }

  setUpdateFunc(v: (b: boolean) => void) {
    this.updateFunc = v
    this.datasetChanged()
  }

  datasetChanged() {
    let allReady: boolean = this.datasets.length > 0
    this.datasets.forEach((e) => {
      allReady = allReady && e.ready
    })

    this.ready = allReady
    if (this.updateFunc) {
      this.updateFunc(this.ready)
    }
  }
}
