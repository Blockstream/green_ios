#ifndef GA_SDK_MEMORY_HPP
#define GA_SDK_MEMORY_HPP
#pragma once

#include <sys/mman.h>

#include <array>
#include <memory>
#include <new>
#include <vector>

#include <wally_core.h>

#include <assertion.hpp>

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
                GA_SDK_VERIFY(wally_bzero(ptr, n));
                munlock(ptr, n);
                m_alloc.deallocate(ptr, n);
            }
        };
    }

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
            wally_bzero(data(), siz);
            munlock(data(), siz);
        }

        secure_array(const secure_array& other) = default;
        secure_array(secure_array&& other) = default;
        secure_array& operator=(secure_array& other) = default;
        secure_array& operator=(secure_array&& other) = default;

        using std::array<T, N>::data;
        using std::array<T, N>::size;
        using std::array<T, N>::begin;
        using std::array<T, N>::end;
    };
}
}

#endif
