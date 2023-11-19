<template>
    <va-card class="mb-2 chart_card">
        <va-card-title>
            Chart card {{ index }}
            <!-- - {{ chart.seriesInfo.name }} -->
        </va-card-title>
        <va-card-title>
            <va-button @click="$emit('removeChart', index)" preset="plain" size="small">
                <va-icon name='material-icons-remove' />
                remove
            </va-button>
        </va-card-title>
        <va-card-content class="chart_content" :class="'chart_count_' + min(chartCount, 3)">
            <va-chart v-if="chartState.ready" :data="chartState.chartData" :options="chartOptions" type="line" />
            <orbit-spinner v-else />
        </va-card-content>
    </va-card>
</template>

<style lang="scss">
.chart_content {
    // height: 400px;
}

.chart_count_1 {
    height: 50vh;
}

.chart_count_2 {
    height: 35vh;
}

.chart_count_3 {
    height: 20vh;
}
</style>

<script lang="ts">

import { Ref, defineComponent, ref } from 'vue'
import VaChart from '../../../components/va-charts/VaChart.vue'
import { ChartState } from './ChartState';
import { OrbitSpinner } from 'epic-spinners'

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
        VaChart,
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
    emits: ["removeChart",],
    watch: {
    },
    data() {
        return {
            chartOptions,
        }
    },
    methods: {
        min(a: any, b: any): any { return a > b ? b : a }
    },
})

</script>
