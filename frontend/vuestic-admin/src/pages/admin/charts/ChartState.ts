
import { Ref, ref } from 'vue'

import formatting from '../../../services/fairyNode/Formatting'
import propertyService from '../../../services/fairyNode/PropertyService'
import { ChartSeries,ChartSeriesListEntry } from '../../../services/fairyNode/PropertyService'

import { TLineChartData } from '../../../data/types'

export class ChartState {
    chartSeries: ChartSeries
    chartData: TLineChartData
    chartDataRef: Ref<TLineChartData>
    ready: Ref<boolean>
    dataDuration: number

    constructor(series: ChartSeries, dataDuration: number) {
        this.chartSeries = series
        this.chartData = <TLineChartData>{}
        this.dataDuration = dataDuration
        this.chartDataRef = ref()
        this.ready = ref(false)

        this.start()
    }

    async start() {
        this.chartData = <TLineChartData>{}
        this.chartData.labels = []
        this.chartData.datasets = [];

        this.chartSeries.values.forEach((entry) => {
            // var history =
            propertyService.valueHistoryLast(entry.global_id, this.dataDuration)
            .then((history)  => {
                this.chartData.datasets.push({
                    label: entry.display_name,
                    data: formatting.transformChartSeries(history.list),
                })

                if(this.chartData.datasets.length == this.chartSeries.values.length){
                    this.chartDataRef.value = this.chartData
                    this.ready.value = true
                }
            })
        })
    }
};
