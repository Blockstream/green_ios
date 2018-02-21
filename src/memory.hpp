#ifndef GA_SDK_SECURE_ALLOCATOR_HPP
#define GA_SDK_SECURE_ALLOCATOR_HPP
#pragma once

#include <sys/mman.h>

#include <memory>
#include <new>
#include <vector>

#include <wally.hpp>

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
                    throw std::bad_alloc();
                }
                return ptr;
            }

            void deallocate(T* ptr, std::size_t n)
            {
                GA_SDK_VERIFY(wally_bzero(ptr, n));
                GA_SDK_RUNTIME_ASSERT(!munlock(ptr, n));
                m_alloc.deallocate(ptr, n);
            }
        };
    }

    template <typename T> using secure_vector = std::vector<T, detail::secure_allocator<T>>;
}
}

#endif
