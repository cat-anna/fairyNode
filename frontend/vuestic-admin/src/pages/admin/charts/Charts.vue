
<template>
    <opts-card
        @DurationChanged="reloadCharts"
        />

    <chart-card
        class="mb-2 chart_card"
        v-for="(chart, index) in charts"
        :chart-state="chart"
        :index="index"
        :chart-count="charts.length"
        @removeChart="removeChart"
        />
        <!-- :class="'chart_count_' + min(charts.length, 3)" -->

    <va-card class="mb-2">
        <va-card-content>
            <orbit-spinner v-if="seriesInfo.length == 0" />
            <va-dropdown v-if="seriesInfo.length > 0" trigger="hover" class="mr-2 mb-2" preset="primary">
                <template #anchor>
                    <va-button>
                        <va-icon :name='"material-icons-add"' />
                        Add Chart
                    </va-button>
                </template>

                <va-dropdown-content>
                    <va-scroll-container class="max-h-[400px]" vertical>
                        <va-list>
                            <va-list-item v-for="series in seriesInfo" class="flex py-1">
                                <va-button plain @click="addChart(series.id)">
                                    {{ series.name }}
                                </va-button>
                            </va-list-item>
                        </va-list>

                    </va-scroll-container>
                </va-dropdown-content>
            </va-dropdown>
        </va-card-content>
    </va-card>
</template>

<style lang="scss">
.chart_card {
    width: 100%;
}
</style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { Ref, defineComponent, ref } from 'vue'
import propertyService from '../../../services/fairyNode/PropertyService'
import { ChartSeries,ChartSeriesListEntry } from '../../../services/fairyNode/PropertyService'
import formatting from '../../../services/fairyNode/Formatting'
import dataTypes from '../../../services/fairyNode/DataTypes'
import { OrbitSpinner } from 'epic-spinners'

import { storeToRefs } from 'pinia'
import { useGlobalStore } from '../../../stores/global-store'

import ChartCard from './ChartCard.vue'
import OptsCard from './OptsCard.vue'
import { ChartState } from './ChartState'

export default defineComponent({
    components: {
        OrbitSpinner,
        ChartCard,
        OptsCard,
    },
    props: { },
    watch: { },
    setup() {
        const { t } = useI18n()
        const charts = ref(new Array<ChartState>())
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
    data() {
        return { }
    },
    mounted() {
        this.refreshSeries()
    },
    unmounted() { },
    methods: {
        addChart(id: string) {
            for(var index in this.seriesInfo)
            {
                var entry : ChartSeries = this.seriesInfo[index]
                if(entry.id == id) {
                    this.charts.push(new ChartState(entry, this.chartDuration))
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

        reloadCharts() {
            this.removeAllCharts()
            this.addedCharts.forEach((id) => this.addChart(id))
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
