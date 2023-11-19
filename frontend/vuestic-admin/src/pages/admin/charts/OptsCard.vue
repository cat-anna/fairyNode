
<template>
    <va-card class="mb-2">
        <va-card-title>opts</va-card-title>
        <va-card-content>
            <va-button-toggle :options="durationTimes" v-model="duration" @update:model-value="setDuration" />
            <!-- v-model="model" -->
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

const durationTimes = [
    { label: "1H", value: 60 * 60, },
    { label: "2H", value: 2 * 60 * 60, },
    { label: "6H", value: 6 * 60 * 60, },
    { label: "12H", value: 12 * 60 * 60, },
    { label: "1D", value: 24 * 60 * 60, },
    { label: "2D", value: 2 * 24 * 60 * 60, },
    { label: "4D", value: 4 * 24 * 60 * 60, },
    { label: "1W", value: 7 * 24 * 60 * 60, },
    { label: "2W", value: 2 * 7 * 24 * 60 * 60, },
    { label: "1M", value: 30 * 7 * 24 * 60 * 60, },
    // "1Y": 365*24*60*60,
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
