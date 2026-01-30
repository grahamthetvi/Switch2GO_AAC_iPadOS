package com.switch2go.aac.settings

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import app.cash.turbine.test
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
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class EditCategoriesViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

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

    private fun createViewModel(): EditCategoriesViewModel {
        return EditCategoriesViewModel(
            categoriesUseCase
        )
    }

    @Test
    fun categories_are_populated() = runTest {
        val vm = createViewModel()
        vm.refreshCategories()

        vm.categoryList.test {
            assertEquals(
                listOf(
                    Category.PresetCategory(PresetCategories.GENERAL.id, 0, false),
                    Category.PresetCategory(PresetCategories.BASIC_NEEDS.id, 1, false),
                    Category.PresetCategory(PresetCategories.PERSONAL_CARE.id, 2, false),
                    Category.PresetCategory(PresetCategories.CONVERSATION.id, 3, false),
                    Category.PresetCategory(PresetCategories.ENVIRONMENT.id, 4, false),
                    Category.PresetCategory(PresetCategories.USER_KEYPAD.id, 5, false),
                    Category.PresetCategory(PresetCategories.RECENTS.id, 6, false),
                ),
                awaitItem()
            )
        }
    }

    @Test
    fun move_category_up() = runTest {
        val vm = createViewModel()
        vm.refreshCategories()
        vm.moveCategoryUp(PresetCategories.RECENTS.id)

        vm.categoryList.test {
            awaitItem() // Skip unmoved emission
            assertEquals(
                listOf(
                    Category.PresetCategory(PresetCategories.GENERAL.id, 0, false),
                    Category.PresetCategory(PresetCategories.BASIC_NEEDS.id, 1, false),
                    Category.PresetCategory(PresetCategories.PERSONAL_CARE.id, 2, false),
                    Category.PresetCategory(PresetCategories.CONVERSATION.id, 3, false),
                    Category.PresetCategory(PresetCategories.ENVIRONMENT.id, 4, false),
                    Category.PresetCategory(PresetCategories.RECENTS.id, 5, false),
                    Category.PresetCategory(PresetCategories.USER_KEYPAD.id, 6, false),
                ),
                awaitItem()
            )
        }
    }

    @Test
    fun move_category_down() = runTest {
        val vm = createViewModel()
        vm.refreshCategories()
        vm.moveCategoryDown(PresetCategories.GENERAL.id)

        vm.categoryList.test {
            awaitItem() // Skip unmoved emission
            assertEquals(
                listOf(
                    Category.PresetCategory(PresetCategories.BASIC_NEEDS.id, 0, false),
                    Category.PresetCategory(PresetCategories.GENERAL.id, 1, false),
                    Category.PresetCategory(PresetCategories.PERSONAL_CARE.id, 2, false),
                    Category.PresetCategory(PresetCategories.CONVERSATION.id, 3, false),
                    Category.PresetCategory(PresetCategories.ENVIRONMENT.id, 4, false),
                    Category.PresetCategory(PresetCategories.USER_KEYPAD.id, 5, false),
                    Category.PresetCategory(PresetCategories.RECENTS.id, 6, false),
                ),
                awaitItem()
            )
        }
    }

}