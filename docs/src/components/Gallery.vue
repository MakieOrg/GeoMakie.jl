<!-- https://codepen.io/heyDante/pen/bxEYOw -->

<script setup lang="ts">
import GalleryImage, { type Props } from './GalleryImage.vue';

defineProps<{
    images: Props[];
}>();
</script>

<template>
    <div class="gallery-image">
        <GalleryImage v-for="image in images" v-bind="image" />
    </div>
</template>

<style scoped>
.heading {
    text-align: center;
    font-size: 2em;
    letter-spacing: 1px;
    padding: 40px;
    color: black;
}

.gallery-image {
    padding: 20px;
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
}

.gallery-image :deep(img) {
    height: 260px;
    width: 300px;
    transform: scale(1);
    transition: transform 0.4s ease;
}
</style>