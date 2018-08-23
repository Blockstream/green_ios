#ifndef GA_SDK_MEMORY_HPP
#define GA_SDK_MEMORY_HPP
#pragma once

#include <sys/mman.h>

#include <array>
#include <memory>
#include <new>
#include <vector>

#include <gsl/gsl_util>

#include "ga_wally.hpp"

namespace ga {
namespace sdk {

    namespace detail {
        template <typename T> class secure_allocator {
        public:
            using value_type = T;

        private:
            std::allocator<T> m_alloc;

        public:
            secure_allocator() = default;
            secure_allocator(const secure_allocator&) = default;
            secure_allocator(secure_allocator&&) = default;
            secure_allocator& operator=(const secure_allocator&) = delete;
            secure_allocator& operator=(secure_allocator&&) = delete;
            ~secure_allocator() = default;

            template <typename U>
            secure_allocator(const secure_allocator<U>& other) noexcept
                : m_alloc(other.m_alloc)
            {
            }

            template <typename U> struct rebind {
                using other = secure_allocator<U>;
            };

            T* allocate(size_t n)
            {
                T* ptr = m_alloc.allocate(n);
                const auto ret = mlock(ptr, n);
                if (ret) {
                    m_alloc.deallocate(ptr, n);
                    throw std::bad_alloc();
                }
                return ptr;
            }

            void deallocate(T* ptr, std::size_t n)
            {
                wally::clear(ptr, n);
                munlock(ptr, n);
                m_alloc.deallocate(ptr, n);
            }
        };
    } // namespace detail

    template <typename T> using secure_vector = std::vector<T, detail::secure_allocator<T>>;

    template <typename T, size_t N> class secure_array : private std::array<T, N> {
    private:
        static constexpr auto siz = N * sizeof(T);

    public:
        secure_array()
            : std::array<T, N>()
        {
            const auto ret = mlock(data(), siz);
            if (ret) {
                throw std::bad_alloc();
            }
        }

        ~secure_array()
        {
            wally::clear(data(), siz);
            munlock(data(), siz);
        }

        secure_array(const secure_array& other) = default;
        secure_array(secure_array&& other) noexcept = default;
        secure_array& operator=(const secure_array& other) = default;
        secure_array& operator=(secure_array&& other) noexcept = default;

        using std::array<T, N>::data;
        using std::array<T, N>::size;
        using std::array<T, N>::begin;
        using std::array<T, N>::end;
        using size_type = typename std::array<T, N>::size_type;
    };

    template <typename T, typename U, typename V> inline void init_container(T& dst, const U& arg1, const V& arg2)
    {
        GA_SDK_RUNTIME_ASSERT(arg1.data() && arg2.data());
        GA_SDK_RUNTIME_ASSERT(
            dst.size() == gsl::narrow<typename T::size_type>(arg1.size() + arg2.size())); // No partial fills supported
        std::copy(arg1.begin(), arg1.end(), dst.data());
        std::copy(arg2.begin(), arg2.end(), dst.data() + arg1.size());
    }
} // namespace sdk
} // namespace ga

#endif
