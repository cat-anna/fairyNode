import formatting from '../../../services/fairyNode/Formatting'
import propertyService from '../../../services/fairyNode/PropertyService'
import { ChartSeries, ChartSeriesListEntry } from '../../../services/fairyNode/PropertyService'
import { TLineChartData } from '../../../data/types'

class DatasetState {
    series: ChartSeriesListEntry
    dataset: any
    owner: any
    lastTimestamp: number = 0
    ready: boolean = false
    dataDuration: number

    constructor(owner: any, series: ChartSeriesListEntry, datasets: Array<any>, dataDuration: number) {
        this.series = series
        this.owner = owner
        this.dataDuration = dataDuration

        this.dataset = {
            label: this.series.display_name,
            data: [],
        }
        datasets.push(this.dataset)

        this.reload()
    }

    reload() {
        this.ready = false
        this.owner.datasetChanged()

        propertyService.valueHistoryLast(this.series.global_id, this.dataDuration)
            .then((history) => {
                this.dataset.data = formatting.transformChartSeries(history.list)

                var last = history.list.at(-1)
                if (last)
                    this.lastTimestamp = last.timestamp
                else
                    this.lastTimestamp = 0

                this.ready = true
                this.owner.datasetChanged()
            })
    }

    setDuration(number: number) {
        this.dataDuration = number
        this.reload()
    }

    update() {
        propertyService.valueHistory(this.series.global_id, this.lastTimestamp)
            .then((update) => {
                var filtered = update.list.filter((e) => this.lastTimestamp < e.timestamp)
                if (filtered.length == 0) {
                    return
                }

                var data = formatting.transformChartSeries(filtered)
                this.dataset.data.push(...data)

                var now = Date.now()
                var millis = formatting.TimestampToMilliseconds(this.dataDuration)

                while(this.dataset.data.length > 0 && (now - this.dataset.data[0].x) > millis){
                    this.dataset.data.shift()
                }

                var last = update.list.at(-1)
                if (last) {
                    this.lastTimestamp = last.timestamp
                }

                this.owner.datasetChanged()
            })
    }
}

export class ChartState {
    chartSeries: ChartSeries
    chartData: TLineChartData
    ready: boolean
    updateFunc?: Function
    datasets: Array<DatasetState>

    constructor(series: ChartSeries, dataDuration: number) {
        this.chartSeries = series
        this.chartData = <TLineChartData>{}
        this.ready = false
        this.datasets = new Array<DatasetState>()

        this.reload(dataDuration)
    }

    async update() {
        this.datasets.forEach((e) => e.update())
    }

    reload(dataDuration: number) {
        this.chartData.labels = []
        this.chartData.datasets = [];
        this.datasets = new Array<DatasetState>()

        this.chartSeries.series.sort((a, b) => {
            return a.display_name.localeCompare(b.display_name)
        })

        this.chartSeries.series.forEach((entry) => {
            this.datasets.push(new DatasetState(this, entry, this.chartData.datasets, dataDuration))
        })
    }

    setDuration(number: number) {
        this.datasets.forEach((e) => {
            e.setDuration(number)
        })
    }

    setUpdateFunc(v: Function) {
        this.updateFunc = v
        this.datasetChanged()
    }

    datasetChanged() {
        var allReady: boolean = this.datasets.length > 0
        this.datasets.forEach((e) => {
            allReady = allReady && e.ready
        })

        this.ready = allReady
        if (this.updateFunc) {
            this.updateFunc(this.ready)
        }
    }
};
