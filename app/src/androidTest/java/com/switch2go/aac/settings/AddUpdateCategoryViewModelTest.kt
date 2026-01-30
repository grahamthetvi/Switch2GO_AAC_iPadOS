package com.switch2go.aac.settings

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.switch2go.aac.CategoriesUseCase
import com.switch2go.aac.FakeUUIDProvider
import com.switch2go.aac.MainDispatcherRule
import com.switch2go.aac.PhrasesUseCase
import com.switch2go.aac.basetest.utils.FakeLocaleProvider
import com.switch2go.aac.presets.Category
import com.switch2go.aac.presets.PresetCategories
import com.switch2go.aac.presets.RoomPresetCategoriesRepository
import com.switch2go.aac.room.RoomPresetPhrasesRepository
import com.switch2go.aac.room.RoomStoredCategoriesRepository
import com.switch2go.aac.room.RoomStoredPhrasesRepository
import com.switch2go.aac.room.VocableDatabase
import com.switch2go.aac.utility.FakeDateProvider
import com.switch2go.aac.utility.StubLegacyCategoriesAndPhrasesRepository
import com.switch2go.aac.utils.locale.LocalesWithText
import com.switch2go.aac.utils.locale.LocalizedResourceUtility
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AddUpdateCategoryViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val database = Room.inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext(),
        VocableDatabase::class.java
    ).build()

    private val presetCategoriesRepository = RoomPresetCategoriesRepository(
        database
    )

    private val storedCategoriesRepository = RoomStoredCategoriesRepository(
        database
    )

    private val presetPhrasesRepository = RoomPresetPhrasesRepository(
        database.presetPhrasesDao(),
        FakeDateProvider()
    )

    private val storedPhrasesRepository = RoomStoredPhrasesRepository(
        database,
        FakeDateProvider()
    )

    private val categoriesUseCase = CategoriesUseCase(
        FakeUUIDProvider(),
        FakeLocaleProvider(),
        storedCategoriesRepository,
        presetCategoriesRepository,
        PhrasesUseCase(
            StubLegacyCategoriesAndPhrasesRepository(),
            storedPhrasesRepository,
            presetPhrasesRepository,
            FakeDateProvider(),
            FakeUUIDProvider(),
            FakeLocaleProvider()
        )
    )

    private fun createViewModel(): AddUpdateCategoryViewModel {
        return AddUpdateCategoryViewModel(
            categoriesUseCase,
            LocalizedResourceUtility(ApplicationProvider.getApplicationContext()),
            FakeLocaleProvider()
        )
    }

    @Test
    fun preset_category_name_updated() = runTest {
        val vm = createViewModel()

        vm.updateCategory(PresetCategories.GENERAL.id, "General 2")

        assertEquals(
            Category.StoredCategory(
                categoryId = PresetCategories.GENERAL.id,
                localizedName = LocalesWithText(mapOf("en_US" to "General 2")),
                hidden = false,
                sortOrder = 0
            ),
            categoriesUseCase.getCategoryById(PresetCategories.GENERAL.id)
        )
    }

}