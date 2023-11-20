
<template>
    <opts-card
        @DurationChanged="updateChartDuration"
        />

    <chart-card
        class="mb-2 chart_card"
        v-for="(chart, index) in charts"
        :chart-state="chart"
        :index="index"
        :chart-count="charts.length"
        @removeChart="removeChart"
        />

    <footer-card
        :series-info="seriesInfo"
        @AddChart="addChart"
        />
</template>

<style lang="scss">
.chart_card {
    width: 100%;
}
</style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { Ref, defineComponent, ref, ShallowReactive, shallowReactive } from 'vue'
import propertyService from '../../../services/fairyNode/PropertyService'
import { ChartSeries,ChartSeriesListEntry } from '../../../services/fairyNode/PropertyService'

import { storeToRefs } from 'pinia'
import { useGlobalStore } from '../../../stores/global-store'

import ChartCard from './ChartCard.vue'
import OptsCard from './OptsCard.vue'
import FooterCard from './FooterCard.vue'
import { ChartState } from './ChartState'

export default defineComponent({
    components: {
        ChartCard,
        OptsCard,
        FooterCard,
    },
    props: { },
    watch: { },
    setup() {
        const { t } = useI18n()
        const charts = ref(new Array<ShallowReactive<ChartState>>())
        const seriesInfo = ref(new Array<ChartSeries>())

        const globalStore = useGlobalStore()
        const { addedCharts, chartDuration } = storeToRefs(globalStore)

        return {
            t,
            charts,
            seriesInfo,
            globalStore,
            addedCharts, chartDuration,
        }
    },
    data() { return { timerId: 0 } },
    mounted() {
        this.refreshSeries()
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => {
                this.updateCharts()
            }, 10 * 1000 )
        }
    },
    unmounted() {
        if (this.timerId != 0) {
            window.clearInterval(this.timerId)
            this.timerId = 0
        }
    },
    methods: {
        addChart(id: string) {
            for(var index in this.seriesInfo) {
                var entry : ChartSeries = this.seriesInfo[index]
                if(entry.id == id) {
                    this.charts.push(shallowReactive(new ChartState(entry, this.chartDuration)))
                    //
                    this.UpdateChartsStore()
                    return
                }
            }
        },
        removeChart(index: number) {
            this.charts.splice(index, 1)
            this.UpdateChartsStore()
        },
        removeAllCharts() { this.charts.length = 0 },
        min(a: any, b: any) { return a > b ? b : a },

        UpdateChartsStore() {
            var lst: string[] = [ ]
            this.charts.forEach((e) => {
                lst.push(e.chartSeries.id)
            })
            this.globalStore.setAddedCharts(lst)
        },

        updateCharts() {
            this.charts.forEach((e) => e.update())
        },
        reloadCharts() {
            this.removeAllCharts()
            this.addedCharts.forEach((id) => this.addChart(id))
        },
        updateChartDuration() {
            this.charts.forEach((e) => e.setDuration(this.chartDuration))
        },
        refreshSeries() {
            propertyService.chartSeries()
            .then((data) => {
                data.sort(function (a, b) {
                    return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                })
                this.seriesInfo = data
                this.reloadCharts()
            })
            .catch(() => {
            })
            .finally(() => {
            })
        }
    }
})
</script>
