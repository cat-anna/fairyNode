<template>
    <va-card class="mb-2 chart_card">
        <va-card-title>
            <div class="w-1/2"> {{ chartState.chartSeries.name }} </div>
            <div class="w-1/4 text-left">
                <VaPopover>
                    <va-icon name='material-icons-info_outline' />
                    <template #body>
                        <p v-for="line in genInfoMessage()">{{ line }}</p>
                    </template>
                </VaPopover>
            </div>
            <div class="w-1/4 text-right">
                <VaPopover :message="t('charts.tips.remove_chart')" placement="left">
                    <va-button @click="$emit('removeChart', index)" preset="plain" size="small">
                        <va-icon name='material-icons-delete' />
                    </va-button>
                </VaPopover>
            </div>
        </va-card-title>

        <va-card-content class="chart_content" :class="'chart_count_' + min(chartCount, 3)">
            <div v-if="ready" class="va-chart">
                <Line v-once ref="chartInstance" :options="chartOptions" :data="chartState.chartData" />
            </div>
            <orbit-spinner v-else />
        </va-card-content>
    </va-card>
</template>

<style lang="scss">
// .chart_content {
    // height: 400px;
// }

.chart_count_1 {
    height: 50vh;
}

.chart_count_2 {
    height: 35vh;
}

.chart_count_3 {
    height: 20vh;
}

.va-chart {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;

    >* {
        height: 100%;
        width: 100%;
    }

    canvas {
        width: 100%;
        height: auto;
    }
}
</style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { defineComponent, ref, Ref, shallowRef, shallowReactive } from 'vue'
// import type {  } from 'vue'
import { ChartState } from './ChartState';
import { OrbitSpinner } from 'epic-spinners'

import { Line } from 'vue-chartjs'
import type { TChartOptions } from 'vue-chartjs/dist/types'

import "./ChartJsUtils"

const chartOptions = {
    maintainAspectRatio: false,
    animation: true,

    plugins: {
        legend: {
            position: 'bottom',
            labels: {
                font: {
                    color: '#34495e',
                    family: 'sans-serif',
                    size: 14,
                },
                usePointStyle: true,
            },
        },
        tooltip: {
            bodyFont: {
                size: 14,
                family: 'sans-serif',
            },
            boxPadding: 4,
        },
    },
    elements: {
        point: {
            radius: 2,
            hoverRadius: 5
        }
    },
    scales: {
        x: {
            type: 'time',
            time: {
            },
            ticks: {
                fontColor: 'rgb(150, 150, 150)',
                maxTicksLimit: 10,
            },
            scaleLabel: {
                fontColor: 'rgb(150, 150, 150)',
                display: true,
            }
        },
        y: {
            type: 'linear',
            // min: 0,
            // max: 2000,
            ticks: {
                fontColor: 'rgb(150, 150, 150)',
            },
            scaleLabel: {
                fontColor: 'rgb(150, 150, 150)',
                display: true,
                labelString: 'value'
            }
        }
    }
}

export default defineComponent({
    components: {
        OrbitSpinner,
        Line,
    },
    props: {
        chartState: {
            required: true,
            type: ChartState,
        },
        index: {
            required: true,
            type: Number,
        },
        chartCount: {
            required: true,
            type: Number,
        }
    },
    emits: ["removeChart"],
    watch: {},
    setup() {
        const { t } = useI18n()
        const chartInstance: Ref<typeof Line | null> = ref(null)
        const opts: TChartOptions<'line'> = chartOptions

        const ready = ref(false)
        return { t, chartInstance, chartOptions: opts, ready }
    },
    mounted() {
        this.chartState.setUpdateFunc((v: boolean) => {
            this.ready = v
            if(this.ready && this.chartInstance)
                this.chartInstance.chart.update()
        })
    },
    methods: {
        min(a: any, b: any): any { return a > b ? b : a },
        reload() {
            this.chartState.reload()
        },
        genInfoMessage() {
            var lines: string[] = []
            var samples = this.t("charts.samples")

            this.chartState.chartData.datasets.forEach((entry) => {
                if (entry.label) {
                    lines.push(entry.label + " - " + entry.data.length + " " + samples)
                }
            })

            return lines;
        }
    },
})

</script>
