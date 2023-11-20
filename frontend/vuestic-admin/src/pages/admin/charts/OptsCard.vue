
<template>
    <va-card class="mb-2">
        <va-card-title>{{ t("charts.options_title")}}</va-card-title>
        <va-card-content>
            <va-button-toggle :options="durationTimes" v-model="duration" @update:model-value="setDuration" />
        </va-card-content>
    </va-card>
</template>

<style lang="scss"></style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { Ref, defineComponent, ref } from 'vue'
import { OrbitSpinner } from 'epic-spinners'

import { storeToRefs } from 'pinia'
import { useGlobalStore } from '../../../stores/global-store'

const hour: number = 60*60
const day: number = 24 * hour
const week: number = 7 * day

const durationTimes = [
    { label: "10M",  value: 10*60, },
    // { label: "30M",  value: 30*60, },
    { label: "1H",  value: 1 * hour, },
    { label: "2H",  value: 2 * hour, },
    { label: "6H",  value: 6 * hour, },
    { label: "12H", value: 12 * hour, },

    { label: "1D",  value: 1 * day, },
    { label: "2D",  value: 2 * day, },
    // { label: "4D",  value: 4 * day, },

    { label: "1W",  value: 1 * week, },
    { label: "2W",  value: 2 * week, },
    { label: "4W",  value: 4 * week, },
]

export default defineComponent({
    components: {
        OrbitSpinner,
    },
    emits: ["DurationChanged"],
    props: {},
    watch: {},
    setup(props, { emit }) {
        const { t } = useI18n()
        const globalStore = useGlobalStore()
        const { chartDuration } = storeToRefs(globalStore)

        return {
            t,
            emit,
            globalStore,
            durationTimes,
            duration: chartDuration,
        }
    },
    data() { return {} },
    mounted() { },
    unmounted() { },
    methods: {
        setDuration(value: number) {
            this.globalStore.setChartDuration(value)
            this.emit('DurationChanged', value)
        }
    }
})
</script>
